#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "pool.h"
#include "repo.h"
#include "util.h"
#include "evr.h"
#include "hash.h"
#include "repo_solv.h"
#include "repo_write.h"

typedef struct _Expander {
  Pool *pool;

  Map ignored;
  Map ignoredx;

  Queue preferposq;
  Map preferpos;
  Map preferposx;

  Map preferneg;
  Map prefernegx;

  Queue conflictsq;
  Map conflicts;

  int debug;
} Expander;

typedef Pool *BSSolv__pool;
typedef Repo *BSSolv__repo;
typedef Expander *BSSolv__expander;


#define MAPEXP(m, n) ((m)->size < (((n) + 7) >> 3) ? map_grow(m, n + 256) : 0)
static inline Id
id2name(Pool *pool, Id id)
{
  while (ISRELDEP(id))
    {
      Reldep *rd = GETRELDEP(pool, id);
      id = rd->name;
    }
  return id;
}

static Id
dep2id(Pool *pool, const char *s)
{
  const char *n;
  Id id;
  int flags;

  while (*s == ' ' || *s == '\t')
    s++;
  n = s;
  while (*s && *s != ' ' && *s != '\t' && *s != '<' && *s != '=' && *s != '>')
    s++;
  id = strn2id(pool, n, s - n, 1);
  if (!*s)
    return id;
  while (*s == ' ' || *s == '\t')
    s++;
  flags = 0;
  for (;;s++)
    {
      if (*s == '<')
	flags |= REL_LT;
      else if (*s == '=')
	flags |= REL_EQ;
      else if (*s == '>')
	flags |= REL_GT;
      else
	break;
    }
  if (!flags)
    return id;
  while (*s == ' ' || *s == '\t')
    s++;
  return rel2id(pool, id, str2id(pool, s, 1), flags, 1);
}

static inline void
expander_installed(Expander *xp, Id p, Map *installed, Map *conflicts, Queue *out, Queue *todo)
{
  Pool *pool = xp->pool;
  Solvable *s = pool->solvables + p;
  Id req, id, *reqp;
  const char *n;

  MAPSET(installed, p);
  queue_push(out, p);
  if (MAPTST(&xp->conflicts, s->name))
    {
      int i;
      for (i = 0; i < xp->conflictsq.count; i++)
	{
	  Id p2, pp2;
	  Id id = xp->conflictsq.elements[i];
	  if (id != s->name)
	    continue;
	  id = xp->conflictsq.elements[i ^ 1];
	  FOR_PROVIDES(p2, pp2, id)
	    {
	      if (pool->solvables[p2].name == id)
		{
		  MAPEXP(conflicts, pool->nsolvables);
	          MAPSET(conflicts, p2);
		}
	    }
	}
    }
  if (s->requires)
    {
      reqp = s->repo->idarraydata + s->requires;
      while ((req = *reqp++) != 0)
	{
	  if (req == SOLVABLE_PREREQMARKER)
	    continue;
	  id = id2name(pool, req);
	  if (MAPTST(&xp->ignored, id))
	    continue;
	  if (MAPTST(&xp->ignoredx, id))
	    {
	      Id xid = str2id(pool, pool_tmpjoin(pool, id2str(pool, s->name), ":", id2str(pool, id)), 0);
	      if (xid && MAPTST(&xp->ignored, xid))
		continue;
	    }
	  n = id2str(pool, id);
	  if (!strncmp(n, "rpmlib(", 7))
	    {
	      MAPEXP(&xp->ignored, id);
	      MAPSET(&xp->ignored, id);
	      continue;
	    }
	  if (*n == '/')
	    {
	      MAPEXP(&xp->ignored, id);
	      MAPSET(&xp->ignored, id);
	      continue;
	    }
	  queue_push2(todo, req, p);
	}
    }
}

#define ERROR_NOPROVIDER 1
#define ERROR_CHOICE	 2


int
expander_expand(Expander *xp, Queue *in, Queue *out)
{
  Pool *pool = xp->pool;
  Queue todo, errors, cerrors, qq, posfoundq;
  Map installed;
  Map conflicts;
  Solvable *s;
  Id q, p, pp;
  int i, j, nerrors, doamb, ignoremarker;
  Id id, who, whon, pn;

  map_init(&installed, pool->nsolvables);
  map_init(&conflicts, 0);
  queue_init(&todo);
  queue_init(&qq);
  queue_init(&errors);
  queue_init(&cerrors);
  queue_init(&posfoundq);

  queue_empty(out);

  /* do direct expands */
  for (i = 0; i < in->count; i++)
    {
      id = in->elements[i];
      q = 0;
      FOR_PROVIDES(p, pp, id)
	{
	  s = pool->solvables + p;
	  if (!pool_match_nevr(pool, s, id))
	    continue;
	  if (q)
	    {
	      q = 0;
	      break;
	    }
	  q = p;
	}
      if (q)
	{
	  if (MAPTST(&installed, q))
	    continue;
	  if (xp->debug)
	    {
	      printf("added %s because of %s (direct dep)\n", id2str(pool, pool->solvables[q].name), dep2str(pool, id));
	      fflush(stdout);
	    }
	  expander_installed(xp, q, &installed, &conflicts, out, &todo); /* unique match! */
	}
      else
	queue_push2(&todo, id, 0);
    }

  doamb = 0;
  ignoremarker = 0;
  queue_push2(&todo, 0, 0);
  while (todo.count)
    {
      id = queue_shift(&todo);
      who = queue_shift(&todo);

      if (!id && !who)	/* found marker */
	{
	  if (!todo.count)
	    break;	/* we're done! */

	  if (doamb)
	    break;	/* amb pass had no progress, stop */

	  if (ignoremarker)
	    {
	      ignoremarker = 0;
	      continue;
	    }

	  if (xp->debug)
	    {
	      printf("now doing undecided dependencies\n");
	      fflush(stdout);
	    }
	  doamb = 1;	/* start amb pass */
	  queue_push2(&todo, 0, 0);
	  continue;
	}

      whon = pool->solvables[who].name;
      queue_empty(&qq);
      FOR_PROVIDES(p, pp, id)
	{
	  Id pn;
	  if (MAPTST(&installed, p))
	    break;
	  pn = pool->solvables[p].name;
	  if (who && MAPTST(&xp->ignored, pn))
	    break;
	  if (who && MAPTST(&xp->ignoredx, pn))
	    {
	      Id xid = str2id(pool, pool_tmpjoin(pool, id2str(pool, whon), ":", id2str(pool, pn)), 0);
	      if (xid && MAPTST(&xp->ignored, xid))
		break;
	    }
	  if (conflicts.size && MAPTST(&conflicts, p))
	    continue;
	  queue_push(&qq, p);
	}
      if (p)
	continue;
      if (qq.count == 0)
	{
	  queue_push(&errors, ERROR_NOPROVIDER);
	  queue_push2(&errors, id, who);
	  continue;
	}
      if (qq.count > 1 && !doamb)
	{
	  /* try again later */
	  queue_push2(&todo, id, who);
	  if (xp->debug)
	    {
	      printf("undecided about %s:%s:", id2str(pool, whon), dep2str(pool, id));
	      for (i = 0; i < qq.count; i++)
	        printf(" %s", id2str(pool, pool->solvables[qq.elements[i]].name));
	      printf("\n");
	      fflush(stdout);
	    }
	  continue;
	}

      /* prune neg prefers */
      if (qq.count > 1)
	{
	  for (i = j = 0; i < qq.count; i++)
	    {
	      p = qq.elements[i];
	      pn = pool->solvables[p].name;
	      if (MAPTST(&xp->preferneg, pn))
		continue;
	      if (who && MAPTST(&xp->prefernegx, pn))
		{
		  Id xid = str2id(pool, pool_tmpjoin(pool, id2str(pool, whon), ":", id2str(pool, pn)), 0);
		  if (xid && MAPTST(&xp->preferneg, xid))
		    continue;
		}
	      qq.elements[j++] = p;
	    }
	  if (j)
	    queue_truncate(&qq, j);
	}

      /* prune pos prefers */
      if (qq.count > 1)
	{
	  queue_empty(&posfoundq);
	  for (i = j = 0; i < qq.count; i++)
	    {
	      p = qq.elements[i];
	      pn = pool->solvables[p].name;
	      if (MAPTST(&xp->preferpos, pn))
		{
		  queue_push2(&posfoundq, pn, p);
		  qq.elements[j++] = p;
		  continue;
		}
	      if (who && MAPTST(&xp->preferposx, pn))
		{
		  Id xid = str2id(pool, pool_tmpjoin(pool, id2str(pool, whon), ":", id2str(pool, pn)), 0);
		  if (xid && MAPTST(&xp->preferpos, xid))
		    {
		      queue_push2(&posfoundq, pn, p);
		      qq.elements[j++] = p;
		      continue;
		    }
		}
	    }
	  if (posfoundq.count == 2)
	    {
	      queue_empty(&qq);
	      queue_push(&qq, posfoundq.elements[1]);
	    }
	  else if (posfoundq.count)
	    {
	      /* found a pos prefer, now find first hit */
	      /* (prefers are ordered) */
	      for (i = 0; i < xp->preferposq.count; i++)
		{
		  Id xid = xp->preferposq.elements[i];
		  for (j = 0; j < posfoundq.count; j += 2)
		    if (posfoundq.elements[j] == xid)
		      break;
		  if (j < posfoundq.count)
		    {
		      queue_empty(&qq);
		      queue_push(&qq, posfoundq.elements[j + 1]);
		      break;
		    }
		}
	    }
	}

      /* prune OR deps */
      if (qq.count > 1 && ISRELDEP(id) && GETRELDEP(pool, id)->flags == REL_OR)
	{
	  Id rid = id;
	  for (;;)
	    {
	      Reldep *rd = 0;
	      if (ISRELDEP(rid))
		{
		  rd = GETRELDEP(pool, rid);
		  if (rd->flags != REL_OR)
		    rd = 0;
		}
	      if (rd)
		rid = rd->name;
	      queue_empty(&qq);
	      FOR_PROVIDES(p, pp, rid)
		queue_push(&qq, p);
	      if (qq.count)
		break;
	      if (rd)
	        rid = rd->evr;
	      else
		break;
	    }
	}
      if (qq.count > 1)
	{
	  queue_push(&cerrors, ERROR_CHOICE);
	  queue_push2(&cerrors, id, who);
	  for (i = 0; i < qq.count; i++)
	    queue_push(&cerrors, qq.elements[i]);
	  queue_push(&cerrors, 0);
	  /* try again later */
	  queue_push2(&todo, id, who);
	  continue;
	}
      if (xp->debug)
	{
	  printf("added %s because of %s:%s\n", id2str(pool, pool->solvables[qq.elements[0]].name), id2str(pool, whon), dep2str(pool, id));
	  fflush(stdout);
	}
      expander_installed(xp, qq.elements[0], &installed, &conflicts, out, &todo);
      if (doamb)
	{
	  /* had progress in amb pass, add new marker */
	  doamb = 0;
	  ignoremarker = 1;	/* ignore marker still on todo list */
	  queue_push2(&todo, 0, 0);	/* add new marker */
	}
      queue_empty(&cerrors);
    }
  map_free(&installed);
  nerrors = 0;
  if (errors.count || cerrors.count)
    {
      queue_empty(out);
      for (i = 0; i < errors.count; i += 3)
	{
	  queue_push(out, errors.elements[i]);
	  queue_push(out, errors.elements[i + 1]);
	  queue_push(out, errors.elements[i + 2]);
	  nerrors++;
	}
      for (i = 0; i < cerrors.count; )
	{
	  queue_push(out, cerrors.elements[i]);
	  queue_push(out, cerrors.elements[i + 1]);
	  queue_push(out, cerrors.elements[i + 2]);
	  i += 3;
	  while (cerrors.elements[i])
	    {
	      queue_push(out, cerrors.elements[i]);
	      i++;
	    }
	  queue_push(out, 0);
	  i++;
	  nerrors++;
	}
    }
  else
    {
      if (todo.count)
	{
	  fprintf(stderr, "Internal expansion error!\n");
	  queue_empty(out);
	  queue_push(out, ERROR_NOPROVIDER);
	  queue_push(out, 0);
	  queue_push(out, 0);
	}
    }
  queue_free(&todo);
  queue_free(&qq);
  queue_free(&errors);
  queue_free(&cerrors);
  queue_free(&posfoundq);
  return nerrors;
}

void
create_considered(Pool *pool)
{
  Map *considered;
  Id p, pb,*best;
  Solvable *s, *sb;
  int ridx;
  Repo *repo;

  if (pool->considered)
    {
      map_free(pool->considered);
      pool->considered = sat_free(pool->considered);
    }
  pool->considered = considered = sat_calloc(sizeof(Map), 1);
  map_init(considered, pool->nsolvables);
  best = sat_calloc(sizeof(Id), pool->ss.nstrings);
  FOR_REPOS(ridx, repo)
    FOR_REPO_SOLVABLES(repo, p, s)
      {
	pb = best[s->name];
	if (pb)
	  {
	    sb = pool->solvables + pb;
	    if (sb->repo != s->repo)
	      continue;
	    if (s->arch >= sb->arch)
	      {
		/* same repo, check versions */
		if (s->evr == sb->evr || evrcmp(pool, sb->evr, s->evr, EVRCMP_COMPARE) >= 0)
		  continue;
	      }
	    MAPCLR(considered, pb);
	  }
	best[s->name] = p;
	MAPSET(considered, p);
      }
  sat_free(best);
}

struct metaline {
  char *l;
  int lastoff;
  int nslash;
  int killed;
};

static int metacmp(const void *ap, const void *bp)
{
  const struct metaline *a, *b;
  int r;

  a = ap;
  b = bp;
  r = a->nslash - b->nslash;
  if (r)
    return r;
  r = strcmp(a->l + 34, b->l + 34);
  if (r)
    return r;
  r = strcmp(a->l, b->l);
  if (r)
    return r;
  return a - b;
}

MODULE = BSSolv		PACKAGE = BSSolv

void
depsort(HV *deps, SV *mapp, SV *cycp, ...)
    PPCODE:
	{
	    int i, j, k, cy, cycstart, nv;
	    SV *sv, **svp;
	    Id id, *e;
	    Id *mark;
	    char **names;
	    Hashmask hm;
	    Hashtable ht;
	    Hashval h, hh;
	    HV *mhv = 0;

	    Queue edata;
	    Queue vedge;
	    Queue todo;
	    Queue cycles;

	    if (items == 3)
	      XSRETURN_EMPTY; /* nothing to sort */
	    if (items == 4)
	      {
		/* only one item */
		char *s = SvPV_nolen(ST(2));
		EXTEND(SP, 1);
		sv = newSVpv(s, 0);
		PUSHs(sv_2mortal(sv));
	        XSRETURN(1); /* nothing to sort */
	      }

	    if (mapp && SvROK(mapp) && SvTYPE(SvRV(mapp)) == SVt_PVHV)
	      mhv = (HV *)SvRV(mapp);

	    queue_init(&edata);
	    queue_init(&vedge);
	    queue_init(&todo);
	    queue_init(&cycles);

	    hm = mkmask(items);
	    ht = sat_calloc(hm + 1, sizeof(*ht));
	    names = sat_calloc(items, sizeof(char *));
	    nv = 1;
	    for (i = 3; i < items; i++)
	      {
		char *s = SvPV_nolen(ST(i));
		h = strhash(s) & hm;
		hh = HASHCHAIN_START;
		while ((id = ht[h]) != 0)
		  {
		    if (!strcmp(names[id], s))
		      break;
		    h = HASHCHAIN_NEXT(h, hh, hm);
		  }
		if (id)
		  continue;	/* had that one before, ignore */
		id = nv++;
		ht[h] = id;
		names[id] = s;
	      }

	    /* we now know all vertices, create edges */
	    queue_push(&vedge, 0);
	    queue_push(&edata, 0);
	    for (i = 1; i < nv; i++)
	      {
		svp = hv_fetch(deps, names[i], strlen(names[i]), 0);
		sv = svp ? *svp : 0;
		queue_push(&vedge, edata.count);
		if (sv && SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVAV)
		  {
		    AV *av = (AV *)SvRV(sv);
		    for (j = 0; j <= av_len(av); j++)
		      {
			char *s;
			STRLEN slen;

			svp = av_fetch(av, j, 0);
			if (!svp)
			  continue;
			sv = *svp;
			s = SvPV(sv, slen);
			if (!s)
			  continue;
			if (mhv)
			  {
			    /* look up in dep map */
			    svp = hv_fetch(mhv, s, slen, 0);
			    if (svp)
			      {
				s = SvPV(*svp, slen);
				if (!s)
				  continue;
			      }
			  }
			/* look up in hash */
			h = strhash(s) & hm;
			hh = HASHCHAIN_START;
			while ((id = ht[h]) != 0)
			  {
			    if (!strcmp(names[id], s))
			      break;
			    h = HASHCHAIN_NEXT(h, hh, hm);
			  }
			if (!id)
			  continue;	/* not known, ignore */
			if (id == i)
			  continue;	/* no self edge */
			queue_push(&edata, id);
		      }
		  }
		queue_push(&edata, 0);
	      }
	    sat_free(ht);

	    if (1)
	      {
		printf("vertexes: %d\n", vedge.count - 1);
		for (i = 1; i < vedge.count; i++)
		  {
		    printf("%d %s:", i, names[i]);
		    Id *e = edata.elements + vedge.elements[i];
		    for (; *e; e++)
		      printf(" %d", *e);
		    printf("\n");
		  }
	      }
		

	    /* now everything is set up, sort em! */
	    mark = sat_calloc(vedge.count, sizeof(Id));
	    for (i = vedge.count - 1; i; i--)
	      queue_push(&todo, i);
	    EXTEND(SP, vedge.count - 1);
	    while (todo.count)
	      {
		i = queue_pop(&todo);
		// printf("check %d\n", i);
		if (i < 0)
		  {
		    i = -i;
		    mark[i] = 2;
		    sv = newSVpv(names[i], 0);
		    PUSHs(sv_2mortal(sv));
		    continue;
		  }
		if (mark[i] == 2)
		  continue;
		if (mark[i] == 0)
		  {
		    int edgestovisit = 0;
		    Id *e = edata.elements + vedge.elements[i];
		    for (; *e; e++)
		      {
			if (*e == -1)
			  continue;	/* broken */
			if (mark[*e] == 2)
			  continue;
			if (!edgestovisit++)
			  queue_push(&todo, -i);
		        queue_push(&todo, *e);
		      }
		    if (!edgestovisit)
		      {
			mark[i] = 2;
			sv = newSVpv(names[i], 0);
			PUSHs(sv_2mortal(sv));
		      }
		    else
		      mark[i] = 1;
		    continue;
		  }
		/* oh no, we found a cycle, record and break it */
		cy = cycles.count;
		for (j = todo.count - 1; j >= 0; j--)
		  if (todo.elements[j] == -i)
		    break;
		cycstart = j;
		// printf("cycle:\n");
		for (j = cycstart; j < todo.count; j++)
		  if (todo.elements[j] < 0)
		    {
		      k = -todo.elements[j];
		      mark[k] = 0;
		      queue_push(&cycles, k);
		      // printf("  %d\n", k);
		    }
	        queue_push(&cycles, 0);
		todo.elements[cycstart] = i;
		/* break it */
		for (k = cy; cycles.elements[k]; k++)
		  ;
		if (!cycles.elements[k])
		  k = cy;
		j = cycles.elements[k + 1] ? cycles.elements[k + 1] : cycles.elements[cy];
		k = cycles.elements[k];
		/* breaking edge from k -> j */
		// printf("break %d -> %d\n", k, j);
		e = edata.elements + vedge.elements[k];
		for (; *e; e++)
		  if (*e == j)
		    break;
		if (!*e)
		  abort();
		*e = -1;
		todo.count = cycstart + 1;
	      }

	    /* recored cycles */
	    if (cycles.count && cycp && SvROK(cycp) && SvTYPE(SvRV(cycp)) == SVt_PVAV)
	      {
		AV *av = (AV *)SvRV(cycp);
		for (i = 0; i < cycles.count;)
		  {
		    AV *av2 = newAV();
		    for (; cycles.elements[i]; i++)
		      {
			SV *sv = newSVpv(names[cycles.elements[i]], 0);
			av_push(av2, sv);
		      }
		    av_push(av, newRV_inc((SV*)av2));
		    i++;
		  }
	      }
	    queue_free(&cycles);

	    queue_free(&edata);
	    queue_free(&vedge);
	    queue_free(&todo);
	    sat_free(mark);
	    sat_free(names);
	}

void
gen_meta(AV *subp, ...)
    PPCODE:
	{
	    Hashmask hm;
	    Hashtable ht;
	    Hashval h, hh;
	    char **subpacks;
	    struct metaline *lines, *lp;
	    int nlines;
	    int i, j, cycle, ns;
	    char *s, *s2, *lo;
	    Id id;
	    Queue cycles;
	    Id cycles_buf[64];

	    if (items == 1)
	      XSRETURN_EMPTY; /* nothing to generate */

	    queue_init_buffer(&cycles, cycles_buf, sizeof(cycles_buf)/sizeof(*cycles_buf));
	    hm = mkmask(av_len(subp) + 2);
	    ht = sat_calloc(hm + 1, sizeof(*ht));
	    subpacks = sat_calloc(av_len(subp) + 2, sizeof(char *));
	    for (j = 0; j <= av_len(subp); j++)
	      {
		SV **svp = av_fetch(subp, j, 0);
		if (!svp)
		  continue;
		s = SvPV_nolen(*svp);
		h = strhash(s) & hm;
		hh = HASHCHAIN_START;
		while ((id = ht[h]) != 0)
		  h = HASHCHAIN_NEXT(h, hh, hm);
		ht[h] = j + 1;
		subpacks[j + 1] = s;
	      }

	    lines = sat_calloc(items - 1, sizeof(*lines));
	    nlines = items - 1;
	    /* lines are of the form "md5sum  pkg/pkg..." */
	    for (i = 0, lp = lines; i < nlines; i++, lp++)
	      {
		s = SvPV_nolen(ST(i + 1));
		if (strlen(s) < 35 || s[32] != ' ' || s[33] != ' ')
		  croak("gen_meta: bad line %s\n", s);
		/* count '/' */
		lp->l = s;
		ns = 0;
		cycle = 0;
		lo = s + 34;
		for (s2 = lo; *s2; s2++)
		  if (*s2 == '/')
		    {
		      if (!cycle)	
			{
			  *s2 = 0;
			  h = strhash(lo) & hm;
			  hh = HASHCHAIN_START;
			  while ((id = ht[h]) != 0)
			    {
			      if (!strcmp(lo, subpacks[id]))
				break;
			      h = HASHCHAIN_NEXT(h, hh, hm);
			    }
			  *s2 = '/';
			  if (id)
			    cycle = 1 + ns;
			}
		      ns++;
		      lo = s2 + 1;
		    }
		if (!cycle)
		  {
		    h = strhash(lo) & hm;
		    hh = HASHCHAIN_START;
		    while ((id = ht[h]) != 0)
		      {
		        if (!strcmp(lo, subpacks[id]))
			  break;
		        h = HASHCHAIN_NEXT(h, hh, hm);
		      }
		    if (id)
		      cycle = 1 + ns;
		  }
		if (cycle)
		  {
		    lp->killed = 1;
		    if (cycle > 1)	/* ignore self cycles */
		      queue_push(&cycles, i);
		  }
		lp->nslash = ns;
		lp->lastoff = lo - s;
	      }
	    sat_free(ht);
	    sat_free(subpacks);

	    /* if we found cycles, prune em */
	    if (cycles.count)
	      {
		char *cycledata = 0;
		int cycledatalen = 0;

		cycledata = sat_extend(cycledata, cycledatalen, 1, 1, 255);
		cycledata[0] = 0;
		cycledatalen += 1;
		hm = mkmask(cycles.count);
		ht = sat_calloc(hm + 1, sizeof(*ht));
		for (i = 0; i < cycles.count; i++)
		  {
		    char *se;
		    s = lines[cycles.elements[i]].l + 34;
		    se = strchr(s, '/');
		    if (se)
		      *se = 0;
		    h = strhash(s) & hm;
		    hh = HASHCHAIN_START;
		    while ((id = ht[h]) != 0)
		      {
		        if (!strcmp(s, cycledata + id))
			  break;
		        h = HASHCHAIN_NEXT(h, hh, hm);
		      }
		    if (id)
		      continue;
		    cycledata = sat_extend(cycledata, cycledatalen, strlen(s) + 1, 1, 255);
		    ht[h] = cycledatalen;
		    strcpy(cycledata + cycledatalen, s);
		    cycledatalen += strlen(s) + 1;
		    if (se)
		      *se = '/';
		  }
		for (i = 0, lp = lines; i < nlines; i++, lp++)
		  {
		    if (lp->killed || !lp->nslash)
		      continue;
		    lo = strchr(lp->l + 34, '/') + 1;
		    for (s2 = lo; *s2; s2++)
		      if (*s2 == '/')
			{
			  *s2 = 0;
			  h = strhash(lo) & hm;
			  hh = HASHCHAIN_START;
			  while ((id = ht[h]) != 0)
			    {
			      if (!strcmp(lo, cycledata + id))
				break;
			      h = HASHCHAIN_NEXT(h, hh, hm);
			    }
			  if (id)
			    {
			      lp->killed = 1;
			      break;
			    }
			  *s2 = '/';
			  lo = s2 + 1;
			}
		    if (lp->killed)
		      continue;
		    h = strhash(lo) & hm;
		    hh = HASHCHAIN_START;
		    while ((id = ht[h]) != 0)
		      {
		        if (!strcmp(lo, cycledata + id))
			  break;
		        h = HASHCHAIN_NEXT(h, hh, hm);
		      }
		    if (id)
		      {
		        lp->killed = 1;
		        break;
		      }
		  }
		sat_free(ht);
		cycledata = sat_free(cycledata);
		queue_free(&cycles);
	      }

	    /* cycles are pruned, now sort array */
	    if (nlines > 1)
	      qsort(lines, nlines, sizeof(*lines), metacmp);

	    hm = mkmask(nlines);
	    ht = sat_calloc(hm + 1, sizeof(*ht));
	    for (i = 0, lp = lines; i < nlines; i++, lp++)
	      {
		if (lp->killed)
		  continue;
		s = lp->l;
		h = strnhash(s, 10);
		h = strhash_cont(s + lp->lastoff, h) & hm;
	        hh = HASHCHAIN_START;
		while ((id = ht[h]) != 0)
		  {
		    struct metaline *lp2 = lines + (id - 1);
		    if (!strncmp(lp->l, lp2->l, 32) && !strcmp(lp->l + lp->lastoff, lp2->l + lp2->lastoff))
		      break;
		    h = HASHCHAIN_NEXT(h, hh, hm);
		  }
		if (id)
		  lp->killed = 1;
		else
		  ht[h] = i + 1;
	      }
	    sat_free(ht);
	    j = 0;
	    for (i = 0, lp = lines; i < nlines; i++, lp++)
	      if (!lp->killed)
		j++;
	    EXTEND(SP, j);
	    for (i = 0, lp = lines; i < nlines; i++, lp++)
	      {
		SV *sv;
		if (lp->killed)
		  continue;
		sv = newSVpv(lp->l, 0);
		PUSHs(sv_2mortal(sv));
	      }
	    sat_free(lines);
	}

MODULE = BSSolv		PACKAGE = BSSolv::pool		PREFIX = pool

PROTOTYPES: ENABLE

BSSolv::pool
new(packname = "BSSolv::pool")
    char *packname;
    CODE:
	RETVAL = pool_create();
	printf("Created pool %p\n", RETVAL);
    OUTPUT:
	RETVAL
    
BSSolv::repo
repofromfile(BSSolv::pool pool, char *filename)
    CODE:
	FILE *fp;
	fp = fopen(filename, "r");
	if (!fp) {
	    croak("%s: %s\n", filename, Strerror(errno));
	    XSRETURN_UNDEF;
	}
	RETVAL = repo_create(pool, 0);
	repo_add_solv(RETVAL, fp);
	fclose(fp);
    OUTPUT:
	RETVAL

BSSolv::repo
repofromstr(BSSolv::pool pool, SV *sv)
    CODE:
	FILE *fp;
	STRLEN len;
	char *buf;
	buf = SvPV(sv, len);
	if (!buf)
	    croak("repofromstr: undef string\n");
	fp = fmemopen(buf, len, "r");
	if (!fp) {
	    croak("fmemopen failed\n");
	    XSRETURN_UNDEF;
	}
	RETVAL = repo_create(pool, 0);
	repo_add_solv(RETVAL, fp);
	fclose(fp);
    OUTPUT:
	RETVAL

void
createwhatprovides(BSSolv::pool pool)
    CODE:
	create_considered(pool);
	pool_createwhatprovides(pool);

void
setdebuglevel(BSSolv::pool pool, int level)
    CODE:
	pool_setdebuglevel(pool, level);

AV *
whatprovides(BSSolv::pool pool, char *str)
    CODE:
	{
	    Id p, pp, id;
	    RETVAL = newAV();
	    sv_2mortal((SV*)RETVAL);
	    id = str2id(pool, str, 0);
	    if (id)
	      FOR_PROVIDES(p, pp, id)
		{
		  SV *reposv = newSV(0);
		  sv_setref_pv(reposv, "BSSolv::repo", (void *)pool->solvables[p].repo);
	          av_push(RETVAL, reposv);
	          av_push(RETVAL, newSViv(p));
		}
	}
    OUTPUT:
	RETVAL

void
DESTROY(BSSolv::pool pool)
    CODE:
	printf("Goodbye pool %p\n", pool);
        if (pool->considered)
	  {
	    map_free(pool->considered);
	    pool->considered = sat_free(pool->considered);
	  }
	pool_free(pool);

MODULE = BSSolv		PACKAGE = BSSolv::repo		PREFIX = repo

AV *
pkgnames(BSSolv::repo repo)
    CODE:
	{
	    Pool *pool = repo->pool;
	    Id p;
	    Solvable *s;
	    RETVAL = newAV();
	    sv_2mortal((SV*)RETVAL);
	    FOR_REPO_SOLVABLES(repo, p, s)
	      {
		av_push(RETVAL, newSVpv(id2str(pool, s->name), 0));
		av_push(RETVAL, newSViv(p));
	      }
	}
    OUTPUT:
	RETVAL

HV *
pkgdata(BSSolv::repo repo, int p)
    CODE:
	{
	    Pool *pool = repo->pool;
	    Solvable *s = pool->solvables + p;
	    AV *av;
	    Id id;
	    const char *ss, *se;
	    unsigned int medianr;

	    if (!s || s->repo != repo)
		XSRETURN_EMPTY;
	    RETVAL = newHV();
	    sv_2mortal((SV*)RETVAL);
	    (void)hv_store(RETVAL, "name", 4, newSVpv(id2str(pool, s->name), 0), 0);
	    ss = id2str(pool, s->evr);
	    se = ss;
	    while (*se >= '0' && *se <= '9')
	      se++;
	    if (se != ss && *se == ':' && se[1])
	      {
		(void)hv_store(RETVAL, "epoch", 5, newSVpvn(ss, se - ss), 0);
		ss = se + 1;
	      }
	    se = strrchr(ss, '-');
	    if (se)
	      {
	        (void)hv_store(RETVAL, "version", 7, newSVpvn(ss, se - ss), 0);
	        (void)hv_store(RETVAL, "release", 7, newSVpv(se + 1, 0), 0);
	      }
	    else
	      (void)hv_store(RETVAL, "version", 7, newSVpv(ss, 0), 0);
	    (void)hv_store(RETVAL, "arch", 4, newSVpv(id2str(pool, s->arch), 0), 0);
	    av = newAV();
	    if (s->provides)
	      {
		Id *pp = repo->idarraydata + s->provides;
		while ((id = *pp++))
		  {
		    if (id == SOLVABLE_FILEMARKER)
		      break;
		    av_push(av, newSVpv(dep2str(pool, id), 0));
		  }
	      }
	    (void)hv_store(RETVAL, "provides", 8, newRV_inc((SV*)av), 0);
	    av = newAV();
	    if (s->requires)
	      {
		Id *pp = repo->idarraydata + s->requires;
		while ((id = *pp++))
		  {
		    if (id == SOLVABLE_PREREQMARKER)
		      continue;
		    ss = dep2str(pool, id);
		    if (*ss == '/')
		      continue;
		    if (*ss == 'r' && !strncmp(ss, "rpmlib(", 7))
		      continue;
		    av_push(av, newSVpv(ss, 0));
		  }
	      }
	    if (solvable_lookup_void(s, SOLVABLE_SOURCENAME))
	      ss = id2str(pool, s->name);
	    else
	      ss = solvable_lookup_str(s, SOLVABLE_SOURCENAME);
	    if (ss)
	      (void)hv_store(RETVAL, "source", 6, newSVpv(ss, 0), 0);
	    (void)hv_store(RETVAL, "requires", 8, newRV_inc((SV*)av), 0);
	    ss = solvable_get_location(s, &medianr);
	    if (ss)
	      (void)hv_store(RETVAL, "path", 4, newSVpv(ss, 0), 0);
	    ss = solvable_lookup_checksum(s, SOLVABLE_PKGID, &id);
	    if (ss && id == REPOKEY_TYPE_MD5)
	      (void)hv_store(RETVAL, "hdrmd5", 4, newSVpv(ss, 0), 0);
	    ss = solvable_lookup_str(s, PUBKEY_FINGERPRINT);
	    if (ss)
	      (void)hv_store(RETVAL, "id", 2, newSVpv(ss, 0), 0);
	}
    OUTPUT:
	RETVAL

void
tofile(BSSolv::repo repo, char *filename)
    CODE:
	{
	    FILE *fp;
	    fp = fopen(filename, "w");
	    if (fp == 0)
	      croak("%s: %s\n", filename, Strerror(errno));
	    repo_write(repo, fp, repo_write_stdkeyfilter, 0, 0);
	    if (fclose(fp))
	      croak("fclose: %s\n",  Strerror(errno));
	}

SV *
tostr(BSSolv::repo repo)
    CODE:
	{
	    FILE *fp;
	    char *buf;
	    size_t len;
	    fp = open_memstream(&buf, &len);
	    if (fp == 0)
	      croak("open_memstream: %s\n", Strerror(errno));
	    repo_write(repo, fp, repo_write_stdkeyfilter, 0, 0);
	    if (fclose(fp))
	      croak("fclose: %s\n",  Strerror(errno));
	    RETVAL = newSVpvn(buf, len);
	    free(buf);
	}
    OUTPUT:
	RETVAL



MODULE = BSSolv		PACKAGE = BSSolv::expander	PREFIX = expander


BSSolv::expander
new(char *packname = "BSSolv::expander", BSSolv::pool pool, HV *config)
    CODE:
	{
	    SV *sv, **svp;
	    char *str;
	    int i, neg;
	    Id id, id2;
	    Expander *xp;

	    xp = calloc(sizeof(Expander), 1);
	    xp->pool = pool;
	    svp = hv_fetch(config, "prefer", 6, 0);
	    sv = svp ? *svp : 0;
	    if (sv && SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVAV)
	      {
		AV *av = (AV *)SvRV(sv);
		for (i = 0; i <= av_len(av); i++)
		  {
		    svp = av_fetch(av, i, 0);
		    if (!svp)
		      continue;
		    sv = *svp;
		    str = SvPV_nolen(sv);
		    if (!str)
		      continue;
		    neg = 0;
		    if (*str == '-')
		      {
			neg = 1;
			str++;
		      }
		    id = str2id(pool, str, 1);
		    id2 = 0;
		    if ((str = strchr(str, ':')) != 0)
		      id2 = str2id(pool, str + 1, 1);
		    if (neg)
		      {
			MAPEXP(&xp->preferneg, id);
			MAPSET(&xp->preferneg, id);
		        if (id2)
			  {
			    MAPEXP(&xp->prefernegx, id2);
			    MAPSET(&xp->prefernegx, id2);
			  }
		      }
		    else
		      {
			queue_push(&xp->preferposq, id);
			MAPEXP(&xp->preferpos, id);
			MAPSET(&xp->preferpos, id);
		        if (id2)
			  {
			    MAPEXP(&xp->preferposx, id2);
			    MAPSET(&xp->preferposx, id2);
			  }
		      }
		  }
	      }
	    svp = hv_fetch(config, "ignoreh", 7, 0);
	    sv = svp ? *svp : 0;
	    if (sv && SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVHV)
	      {
		HV *hv = (HV *)SvRV(sv);
		HE *he;

		hv_iterinit(hv);
		while ((he = hv_iternext(hv)) != 0)
		  {
		    I32 strl;
		    str = hv_iterkey(he, &strl);
		    if (!str)
		      continue;
		 
		    id = str2id(pool, str, 1);
		    id2 = 0;
		    if ((str = strchr(str, ':')) != 0)
		      id2 = str2id(pool, str + 1, 1);
		    MAPEXP(&xp->ignored, id);
		    MAPSET(&xp->ignored, id);
		    if (id2)
		      {
			MAPEXP(&xp->ignoredx, id2);
		        MAPSET(&xp->ignoredx, id2);
		      }
		  }
	      }
	    svp = hv_fetch(config, "conflict", 8, 0);
	    sv = svp ? *svp : 0;
	    if (sv && SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVAV)
	      {
		AV *av = (AV *)SvRV(sv);
		for (i = 0; i <= av_len(av); i++)
		  {
		    char *p;
		    Id id2;

		    svp = av_fetch(av, i, 0);
		    if (!svp)
		      continue;
		    sv = *svp;
		    str = SvPV_nolen(sv);
		    if (!str)
		      continue;
		    p = strchr(str, ':');
		    if (!p)
		      continue;
		    id = strn2id(pool, str, p - str, 1);
		    str = p + 1;
		    while ((p = strchr(str, ',')) != 0)
		      {
			id2 = strn2id(pool, str, p - str, 1);
			queue_push2(&xp->conflictsq, id, id2);
			MAPEXP(&xp->conflicts, id);
			MAPSET(&xp->conflicts, id);
			MAPEXP(&xp->conflicts, id2);
			MAPSET(&xp->conflicts, id2);
			str = p + 1;
		      }
		    id2 = str2id(pool, str, 1);
		    queue_push2(&xp->conflictsq, id, id2);
		    MAPEXP(&xp->conflicts, id);
		    MAPSET(&xp->conflicts, id);
		    MAPEXP(&xp->conflicts, id2);
		    MAPSET(&xp->conflicts, id2);
		  }
	      }
	    sv = get_sv("Build::expand_dbg", FALSE);
	    if (sv && SvIV(sv))
	      xp->debug = 1;
	    RETVAL = xp;
	    printf("Created expander %p\n", RETVAL);
	}
    OUTPUT:
	RETVAL


void
expand(BSSolv::expander xp, ...)
    PPCODE:
	{
	    Pool *pool;
	    int i, nerrors;
	    Id id, who;
	    Queue revertignore, in, out;

	    queue_init(&revertignore);
	    queue_init(&in);
	    queue_init(&out);
	    pool = xp->pool;
	    for (i = 1; i < items; i++)
	      {
		char *s = SvPV_nolen(ST(i));
		if (*s == '-')
		  {
		    Id id = str2id(pool, s + 1, 1);
		    MAPEXP(&xp->ignored, id);
		    if (MAPTST(&xp->ignored, id))
		      continue;
		    MAPSET(&xp->ignored, id);
		    queue_push(&revertignore, id);
		    if ((s = strchr(s + 1, ':')) != 0)
		      {
			id = str2id(pool, s + 1, 1);
			MAPEXP(&xp->ignored, id);
			if (MAPTST(&xp->ignoredx, id))
			  continue;
			MAPSET(&xp->ignoredx, id);
			queue_push(&revertignore, -id);
		      }
		  }
		else
		  {
		    Id id = dep2id(pool, s);
		    queue_push(&in, id);
		  }
	      }

	    MAPEXP(&xp->ignored, pool->ss.nstrings);
	    MAPEXP(&xp->ignoredx, pool->ss.nstrings);
	    MAPEXP(&xp->preferpos, pool->ss.nstrings);
	    MAPEXP(&xp->preferposx, pool->ss.nstrings);
	    MAPEXP(&xp->preferneg, pool->ss.nstrings);
	    MAPEXP(&xp->prefernegx, pool->ss.nstrings);
	    MAPEXP(&xp->conflicts, pool->ss.nstrings);

	    nerrors = expander_expand(xp, &in, &out);

	    /* revert ignores */
	    for (i = 0; i < revertignore.count; i++)
	      {
		id = revertignore.elements[i];
		if (id > 0)
		  MAPCLR(&xp->ignored, id);
		else
		  MAPCLR(&xp->ignoredx, -id);
	      }

	    if (nerrors)
	      {
		EXTEND(SP, nerrors + 1);
		PUSHs(sv_2mortal(newSV(0)));
		for (i = 0; i < out.count; )
		  {
		    SV *sv;
		    Id type = out.elements[i];
		    if (type == ERROR_NOPROVIDER)
		      {
			id = out.elements[i + 1];
			who = out.elements[i + 2];
			if (who)
		          sv = newSVpvf("nothing provides %s needed by %s", dep2str(pool, id), id2str(pool, pool->solvables[who].name));
			else
		          sv = newSVpvf("nothing provides %s", dep2str(pool, id));
			i += 3;
		      }
		    else if (type == ERROR_CHOICE)
		      {
			int j;
			char *str = "";
			for (j = i + 3; out.elements[j]; j++)
			  {
			    Solvable *s = pool->solvables + out.elements[j];
			    str = pool_tmpjoin(pool, str, " ", id2str(pool, s->name));
			  }
			if (*str)
			  str += 2;
			id = out.elements[i + 1];
			who = out.elements[i + 2];
			if (who)
		          sv = newSVpvf("have choice for %s needed by %s: %s", dep2str(pool, id), id2str(pool, pool->solvables[who].name), str);
			else
		          sv = newSVpvf("have choice for %s: %s", dep2str(pool, id), str);
			i = j + 1;
		      }
		    else
		      croak("expander: bad error type\n");
		    PUSHs(sv_2mortal(sv));
		  }
	      }
	    else
	      {
		EXTEND(SP, out.count + 1);
		PUSHs(sv_2mortal(newSViv((IV)1)));
		for (i = 0; i < out.count; i++)
		  {
		    Solvable *s = pool->solvables + out.elements[i];
		    PUSHs(sv_2mortal(newSVpv(id2str(pool, s->name), 0)));
		  }
	      }
	}

void
DESTROY(BSSolv::expander xp)
    CODE:
	printf("Goodbye expander %p\n", xp);
	map_free(&xp->ignored);
	map_free(&xp->ignoredx);
	queue_free(&xp->preferposq);
	map_free(&xp->preferpos);
	map_free(&xp->preferposx);
	map_free(&xp->preferneg);
	map_free(&xp->prefernegx);
	queue_free(&xp->conflictsq);
	map_free(&xp->conflicts);
	sat_free(xp);
