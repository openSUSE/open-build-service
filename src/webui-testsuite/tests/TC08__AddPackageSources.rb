class TC08__AddPackageSources < TestCase


  test :add_new_source_file_to_home_project_package do
  depend_on :create_home_project_package_for_user
    
    navigate_to PackageSourcesPage,
      :project => "home:user1",
      :package => "HomePackage1",
      :user => $data[:user1]
    open_add_file
    add_file :name => "HomeSourceFile1"
  end


  test :add_new_source_file_to_subproject_package do
  depend_on :create_subproject_package_for_user
    
    navigate_to PackageSourcesPage,
      :project => "home:user1:SubProject1",
      :package => "SubPackage1",
      :user => $data[:user1]
    open_add_file
    add_file :name => "SubSourceFile1"
 end


  test :add_new_source_file_to_global_project_package do
  depend_on :create_global_project_package
    
    navigate_to PackageSourcesPage,
      :project => "PublicProject1",
      :package => "PublicPackage1",
      :user => $data[:admin]
    open_add_file
    add_file :name => "PublicSourceFile1"
  end


  test :add_source_file_from_url do
  skip
  
    remote_file_url = "https://www.gitorious.org\
/obs-webui-testsuite/obs-webui-testsuite/blobs/raw/master/COPYING"

  end


  test :add_source_file_from_local_file do
  depend_on :create_home_project_package_for_user
    
    source_file = File.new "HomeSourceFile2.cc", "w"
    source_file.write NORMAL_SOURCE
    source_file.close
    
    navigate_to PackageSourcesPage,
      :project => "home:user1",
      :package => "HomePackage1",
      :user => $data[:user1]
    open_add_file
    add_file(
      :upload_from => :local_file,
      :upload_path => File.expand_path(source_file.path) )
  end
  
    
  test :add_source_file_from_local_file_override_name do
  depend_on :create_home_project_package_for_user
    
    source_file = File.new "MySourceFile.cc", "w"
    source_file.write NORMAL_SOURCE
    source_file.close
    
    navigate_to PackageSourcesPage,
      :project => "home:user1",
      :package => "HomePackage1",
      :user => $data[:user1]
    open_add_file
    add_file(
      :name => "HomeSourceFile3",
      :upload_from => :local_file,
      :upload_path => File.expand_path(source_file.path) )
  end
  
  
  test :add_source_file_from_big_local_file do
  depend_on :create_home_project_package_for_user
    
    source_file = File.new "BigSourceFile.c", "w"
    source_file.write BIG_SOURCE
    source_file.close
    
    navigate_to PackageSourcesPage,
      :project => "home:user1",
      :package => "HomePackage1",
      :user => $data[:user1]
    open_add_file
    add_file(
      :upload_from => :local_file,
      :upload_path => File.expand_path(source_file.path) )
  end
  
  
  test :add_source_file_from_empty_local_file do
  depend_on :create_home_project_package_for_user
    
    source_file = File.new "EmptySource1.c", "w"
    source_file.close
    
    navigate_to PackageSourcesPage,
      :project => "home:user1",
      :package => "HomePackage1",
      :user => $data[:user1]
    open_add_file
    add_file(
      :upload_from => :local_file,
      :upload_path => File.expand_path(source_file.path) )
  end
  
  
  test :add_source_file_from_empty_url do
  depend_on :create_home_project_package_for_user
  
    skip # known failure TODO
    navigate_to PackageSourcesPage,
      :project => "home:user1",
      :package => "HomePackage1",
      :user => $data[:user1]
    open_add_file
    add_file(
      :name => "missing_remote_source.html",
      :upload_from => :remote_url,
      :upload_path => "",
      :expect => :invalid_upload_path)
  end


  test :add_source_file_from_invalid_local_path do
  depend_on :create_home_project_package_for_user
  
    skip # you can not test that with firefox, it won't allow uploads of non existant files
    navigate_to PackageSourcesPage,
      :project => "home:user1",
      :package => "HomePackage1",
      :user => $data[:user1]
    open_add_file
    add_file(
      :upload_from => :local_file,
      :upload_path => '/dqdqwdqw/fdewfewfwe/gretrher/fwefwefwef',
      :expect => :invalid_upload_path)
  end


  test :add_source_file_from_invalid_url do
  depend_on :create_package_with_only_name
 
    skip # service file is created that will fail - somewhen 
    navigate_to PackageSourcesPage,
      :project => "home:user1",
      :package => "HomePackage-OnlyName",
      :user => $data[:user1]
    open_add_file
    add_file(
      :upload_from => :remote_url,
      :upload_path => 'http://no.such.remote.file.dude/path',
      :name => "path",
      :expect => :download_failed)
  end
  
  
  test :add_source_file_with_invalid_name do
  depend_on :create_home_project_package_for_user
  
    navigate_to PackageSourcesPage,
      :project => "home:user1",
      :package => "HomePackage1",
      :user => $data[:user1]
    open_add_file
    add_file(
      :name => "\/\/ invalid name",
      :upload_from => :local_file,
      :expect => :invalid_upload_path)
  end


  test :add_source_file_all_fields_empty do
  depend_on :create_home_project_package_for_user
  
    navigate_to PackageSourcesPage,
      :project => "home:user1", :package => "HomePackage1", :user => $data[
      :user1]
    open_add_file
    add_file(
      :name => "",
      :upload_path => "",
      :expect => :invalid_upload_path)
  end
  
  
  # RUBY CODE ENDS HERE.
  # BELOW ARE APPENDED ALL DATA STRUCTURES USED BY THE TESTS.
  


# -------------------------------------------------------------------------------------- #
NORMAL_SOURCE = <<CODE_END
#include <QApplication>
#include <QDir>
#include <QFileInfo>
#include <QMessageBox>
#include <QProcess>
#include <QString>
#include <QTextStream>
#include <stdlib.h>
#include "gamestoreform.h"

QString detectDistro()
{
  QFileInfo fi("/etc/SuSE-release");
  if (fi.exists()) return "openSUSE";
  return "";
}

bool detect3D()
{
  QProcess glxinfo;
  glxinfo.start("glxinfo");
  if (!glxinfo.waitForStarted(1000)) return false;
  if (!glxinfo.waitForFinished(1000)) return false;
  QByteArray o = glxinfo.readAll();
  return ( o.indexOf(QByteArray("direct rendering: Yes")) > -1 );
}

int main( int argc, char *argv[] )
{
  QApplication app( argc, argv );

  GameStoreInfo::distro = detectDistro();
  if (GameStoreInfo::distro.isEmpty()) {
    QMessageBox::critical(0, "Error", "Game Store was unable to detect your distribution.");
    return 1;
  }

  char *tmp = getenv("XDG_CACHE_HOME");
  GameStoreInfo::cachedir = tmp ? tmp : QDir::homePath() + "/.cache";
  GameStoreInfo::cachedir += + "/gamestore/";
  QDir dir;
  dir.mkpath(GameStoreInfo::cachedir + "icon");
  dir.mkpath(GameStoreInfo::cachedir + "thumb");

  GameStoreForm *window = new GameStoreForm();
  window->show();

  if (!detect3D()) {
    QMessageBox::warning(0, "Warning", "Your system reports that it is not capable of hardware accelerated 3D graphics. You might expect difficulties running some of the games.\nUsually the cause of this error is that there are no drivers for your graphics card installed.");
  }

  return app.exec();
}
CODE_END
# -------------------------------------------------------------------------------------- #
  
  
  
  
  
  
  
  
  
  
  
# -------------------------------------------------------------------------------------- #
BIG_SOURCE = <<CODE_END
 *
 * util.c        Utility functions for linuxrc
 *
 * Copyright (c) 1996-2008  Hubert Mantel, SuSE Linux AG (mantel@suse.de)
 *
 */

#define __LIBRARY__

#define _GNU_SOURCE /* stat64, asprintf */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdarg.h>
#include <ctype.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/vfs.h>
#include <sys/mount.h>
#include <sys/ioctl.h>
#include <sys/kd.h>
#include <sys/utsname.h>
#include <sys/wait.h>
#include <sys/klog.h>
#include <fcntl.h>
#include <time.h>
#include <syscall.h>
#include <dirent.h>
#include <errno.h>
#include <fnmatch.h>
#include <signal.h>
#include <sys/swap.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <utime.h>
#include <net/if.h>
#include <linux/major.h>
#include <linux/raid/md_u.h>
#include <execinfo.h>

#define CDROMEJECT  0x5309  /* Ejects the cdrom media */

#include <linux/posix_types.h>
#undef dev_t
#define dev_t __kernel_dev_t
#include <linux/loop.h>
#undef dev_t

#include "global.h"
#include "display.h"
#include "util.h"
#include "window.h"
#include "module.h"
#include "keyboard.h"
#include "text.h"
#include "dialog.h"
#include "net.h"
#include "auto2.h"
#include "file.h"
#include "lsh.h"
#include "bootpc.h"
#include "fstype.h"
#include "mkdevs.h"
#include "scsi_rename.h"
#include "utf8.h"
#include "url.h"
#include "linuxrc.h"

#define LED_TIME     50000

typedef struct {
  instmode_t scheme;
  char *server;
  char *share;
  char *dir;
  char *user;
  char *password;
  char *domain;
  unsigned port;
} url1_t;

static void show_lsof_info(FILE *f, unsigned pid);
static void show_ps_info(FILE *f, unsigned pid);

static struct hlink_s {
  struct hlink_s *next;
  dev_t dev;
  ino_t ino;
  char *dst;
} *hlink_list = NULL;

static char *exclude = NULL;
static int rec_level = 0;
static int extend_ready = 0;

static void add_flag(slist_t **sl, char *buf, int value, char *name);

static int do_cp(char *src, char *dst);
static char *walk_hlink_list(ino_t ino, dev_t dev, char *dst);
static void free_hlink_list(void);

static void add_driver_update(char *dir, char *loc);
static int cmp_dir_entry(slist_t *sl0, slist_t *sl1);
static int cmp_dir_entry_s(const void *p0, const void *p1);
static void create_update_name(unsigned idx);

static char *read_symlink(char *name);
static void scsi_rename_devices(void);
static void scsi_rename_onedevice(char **dev);

static int skip_spaces(unsigned char **str);
static int word_size(unsigned char *str, int *width, int *enc_len);

static void util_extend_usr1(int signum);
static int util_extend(char *extension, char task, int verbose);


void util_redirect_kmsg()
{
  static char newvt[2] = { 11, 4 /* console 4 */ };
  int fd, loglevel;

  loglevel = config.loglevel;

  /* serial: default to 1 (no logging) */
  if(!loglevel && config.serial) loglevel = 1;

  if(loglevel) klogctl(8, NULL, loglevel);

  if(!config.serial && (fd = open(config.console, O_RDONLY))) {
    ioctl(fd, TIOCLINUX, &newvt);
    close(fd);
    /* 'create' console 4 */
    fd = open("/dev/tty4", O_RDWR);
    close(fd);
  }
}


/*
 * Center text.
 */
void util_center_text(unsigned char *txt, int max_width)
{
  int width, pre, post, len;

  width = utf8_strwidth(txt);
  len = strlen(txt);

  /* functions seem to expect max_width to include the final '\0'. */
  max_width--;

  if(width >= max_width) return;

  pre = (max_width - width) / 2;
  post = max_width - width - pre;

  if(len) memmove(txt + pre, txt, len);
  if(pre) memset(txt, ' ', pre);
  if(post) memset(txt + pre + len, ' ', post);
  txt[pre + len + post] = 0;

#if 0
  fprintf(stderr, "[center %d->%d: <%s>]\n", width, max_width, txt);
#endif
}


/*
 * Left-align text.
 */
void util_fill_string(unsigned char *str, int max_width)
{
  int width, len;

  /* functions seem to expect max_width to include the final '\0'. */
  max_width--;

  width = utf8_strwidth(str);
  len = strlen(str);

  while(width++ < max_width) {
    str[len++] = ' ';
    str[len] = 0;
  }
}


void util_generate_button(button_t *button, char *txt, int size)
{
  size = size > BUTTON_SIZE_NORMAL ? BUTTON_SIZE_LARGE : BUTTON_SIZE_NORMAL;

  memset(button, 0, sizeof *button);
  utf8_strwcpy(button->text, txt, size);

  util_center_text(button->text, size + 1);
}


int skip_spaces(unsigned char **str)
{
  int spaces = 0;

  while(**str && (**str == ' ' || **str == '\t')) {
    (*str)++;
    spaces++;
  }

  return spaces;
}


int word_size(unsigned char *str, int *width, int *enc_len)
{
  unsigned char *s;
  int c;

  *width = *enc_len = 0;

  if(!*str) return 0;

  s = str;

  if(skip_spaces(&s)) {
    *width = (!*s || *s == '\n') ? 0 : 1;
    *enc_len = s - str;

    return 1;
  }

  while(*s && *s != ' ' && *s != '\t' && *s != '\n') {
    if(!(c = utf8_decode(s))) break;
    s += utf8_enc_len(*s);
    *width += utf32_char_width(c);
    if(c >= 0x3000) break;
  }

  *enc_len = s - str;

  return 0;
}


/*
 * Add linebreaks to txt.
 * Returns number of lines put into the lines array.
 */
int util_format_txt(unsigned char *txt, unsigned char **lines, int max_width)
{
  int line, pos, width, w_width, w_enc_len, w_space;

#if 0
  fprintf(stderr, "[format: %d <%s> = ", max_width, txt);
#endif

  line = 0;
  *(lines[line] = malloc(UTF8_SIZE(max_width))) = 0;

  width = pos = 0;
  skip_spaces(&txt);

  while(*txt) {
    if(*txt == '\n') {
      w_width = w_enc_len = 0;
      w_space = 1;
      txt++;
      skip_spaces(&txt);
    }
    else {
      w_space = word_size(txt, &w_width, &w_enc_len);

#if 0
      fprintf(stderr, "{<%s> %d %d %d}", txt, w_width, w_enc_len, w_space);
#endif

      if(w_width + width <= max_width || width == 0) {
        if(w_width && w_enc_len) {
          if(w_space) {
            lines[line][pos++] = ' ';
            lines[line][pos] = 0;
          }
          else {
            memcpy(lines[line] + pos, txt, w_enc_len);
            lines[line][pos += w_enc_len] = 0;
          }
        }
        width += w_width;
        txt += w_enc_len;
        continue;
      }
    }

    if(line >= MAX_Y - 1) break;
    *(lines[++line] = malloc(UTF8_SIZE(max_width))) = 0;
    width = pos = 0;
    if(!w_space && w_enc_len) {
      memcpy(lines[line] + pos, txt, w_enc_len);
      lines[line][pos += w_enc_len] = 0;
      width += w_width;
    }

    txt += w_enc_len;
  }

  line++;

  for(pos = 0; pos < line; pos++) {
    width = strlen(lines[pos]);
    while(width > 0 && lines[pos][width - 1] == ' ') lines[pos][--width] = 0;
    util_center_text(lines[pos], max_width);
  }

#if 0
  for(pos = 0; pos < line; pos++) fprintf(stderr, " <%s>", lines[pos]);
  fprintf(stderr, "]\n");
#endif

  return line;
}


void util_create_items (item_t items_arr [], int nr_iv, int size_iv)
    {
    int  i_ii;

    for (i_ii = 0; i_ii < nr_iv; i_ii++)
        {
        items_arr [i_ii].text = malloc (UTF8_SIZE(size_iv));
        items_arr [i_ii].func = 0;
        items_arr [i_ii].di = 0;
        }
    }


void util_free_items (item_t items_arr [], int nr_iv)
    {
    int  i_ii;

    for (i_ii = 0; i_ii < nr_iv; i_ii++)
        free (items_arr [i_ii].text);
    }


/*
 * FIXME: can't get >32-bit sizes, but the size feature is currently not
 * used, so it doesn't matter. -> Remove size parameter later.
 */
int util_fileinfo(char *file_name, int *size, int *compressed)
{
  unsigned char buf[4];
  int fd, err = 0;
  off_t ofs;

  if(size) *size = 0;
  if(compressed) *compressed = 0;

  if(!(fd = open(file_name, O_RDONLY | O_LARGEFILE))) return -1;

  if(read(fd, buf, 2) != 2) {
    close(fd);
    return -1;
  }

  if(buf[0] == 0x1f && (buf[1] == 0x8b || buf[1] == 0x9e)) {
    if(
      lseek(fd, (off_t) -4, SEEK_END) == (off_t) -1 ||
      read(fd, buf, 4) != 4
    ) {
      err = -1;
    }
    else {
      if(size) *size = (buf[3] << 24) + (buf[2] << 16) + (buf[1] << 8) + buf[0];
      if(compressed) *compressed = 1;
    }
  }
  else {
    if(size) {
      ofs = lseek(fd, 0, SEEK_END);
      if(ofs != -1) {
        *size = ofs;
      }
      else {
        err = -1;
      }
    }
  }

  close(fd);

  return err;
}


void util_update_kernellog (void)
    {
    FILE  *outfile_pri;
    FILE  *lastfile_pri;
    FILE  *bootmsg_pri;
    char   buffer_ti [1 << 19];
    char   line_ti [MAX_X - 30];
    int    i_ii = 1;
    int    pos_ii;
    int    size_ii;


    outfile_pri = fopen (kernellog_tg, "a");
    if (!outfile_pri)
        return;

    lastfile_pri = fopen (lastlog_tg, "w");
    if (!lastfile_pri)
        {
        fclose (outfile_pri);
        return;
        }

    bootmsg_pri = fopen (bootmsg_tg, "a");

    size_ii = klogctl (3, buffer_ti, sizeof (buffer_ti));

    if (size_ii > 0 && bootmsg_pri)
        fwrite (buffer_ti, 1, size_ii, bootmsg_pri);

    if (bootmsg_pri) fclose (bootmsg_pri);

    for (pos_ii = 0; pos_ii < size_ii; pos_ii++)
        {
        line_ti [i_ii] = buffer_ti [pos_ii];
        if (line_ti [i_ii] == '\n' || i_ii >= (int) sizeof (line_ti) - 2)
            {
            line_ti [i_ii + 1] = 0;
            if (line_ti [1] == '<')
                {
                fputs (line_ti + 4, outfile_pri);
                fputs (line_ti + 4, lastfile_pri);
                }
            else
                {
                fputs (line_ti + 1, outfile_pri);
                fputs (line_ti + 1, lastfile_pri);
                }
            i_ii = 0;
            }

        ++i_ii;
        }

    klogctl (5, 0, 0);

    fclose (outfile_pri);
    fclose (lastfile_pri);
    }


void util_print_banner (void)
    {
    window_t       win_ri;
    char           text_ti [UTF8_SIZE(MAX_X)];
    struct utsname utsinfo_ri;

    if(!config.win) return;

    uname (&utsinfo_ri);
    if (config.linemode) {
      printf (">>> Linuxrc v" LXRC_FULL_VERSION " (Kernel %s) <<<\n", utsinfo_ri.release);
        return;
    }
    memset (&win_ri, 0, sizeof (window_t));
    win_ri.x_left = 1;
    win_ri.y_left = 1;
    win_ri.x_right = max_x_ig;
    win_ri.y_right = max_y_ig;
    win_ri.style = STYLE_RAISED;
    win_ri.head = 3;
    if (colors_prg->has_colors)
        {
        win_ri.bg_color = colors_prg->bg;
        win_ri.fg_color = COL_BLACK;
        }
    else
        {
        win_ri.bg_color = colors_prg->msg_win;
        win_ri.fg_color = colors_prg->msg_fg;
        }
    win_open (&win_ri);
    win_clear (&win_ri);

    win_ri.x_left = 2;
    win_ri.y_left = 2;
    win_ri.x_right = max_x_ig - 1;
    win_ri.y_right = 4;
    win_ri.head = 0;
    win_ri.style = STYLE_SUNKEN;
    win_open (&win_ri);

    sprintf (text_ti, ">>> Linuxrc v" LXRC_FULL_VERSION " (Kernel %s) <<<",
             utsinfo_ri.release);
    util_center_text (text_ti, max_x_ig - 4);
    disp_set_color (colors_prg->has_colors ? COL_BWHITE : colors_prg->msg_fg,
                    win_ri.bg_color);
    win_print (&win_ri, 1, 1, text_ti);
    fflush (stdout);
    }


void util_beep (int  success_iv)
    {
    int  fd_ii;


    fd_ii = open ("/dev/console", O_RDWR);
    if (fd_ii < 0)
        return;

    ioctl (fd_ii, KDMKTONE, (150 << 16) | 1000);
    usleep (150 * 1000);

    if (success_iv)
        ioctl (fd_ii, KDMKTONE, (150 << 16) | 4000);
    else
        {
        ioctl (fd_ii, KDMKTONE, (150 << 16) | 1000);
        usleep (150 * 1000);
        ioctl (fd_ii, KDMKTONE, (150 << 16) | 1000);
        }

    close (fd_ii);
    }


/*
 * Do we really need this?
 *
 * Never lengthen the string!
 */
void util_truncate_dir(char *dir)
{
  int l;

  if(!dir) return;

  l = strlen(dir);

  if(l > 1 && dir[l - 1] == '/') dir[l - 1] = 0;
}


/*
 * Check whether 'file' exists and return file type.
 *
 * return:
 *   0: does not exists
 *   'r', 'd', 'b', 1: type (1: other)
 */
int util_check_exist(char *file)
{
  struct stat64 sbuf;

  if(!file || stat64(file, &sbuf)) return 0;

  if(S_ISREG(sbuf.st_mode)) return 'r';
  if(S_ISDIR(sbuf.st_mode)) return 'd';
  if(S_ISBLK(sbuf.st_mode)) return 'b';

  return 1;
}


/*
 * Check whether 'dir/file' exists and return file type.
 *
 * return:
 *   0: does not exists
 *   'r', 'd', 'b', 1: type (1: other)
 */
int util_check_exist2(char *dir, char *file)
{
  char *buf = NULL;
  int type;

  if(!dir || !file) return 0;

  strprintf(&buf, "%s/%s", dir, file);
  type = util_check_exist(buf);
  str_copy(&buf, NULL);

  return type;
}


int util_check_break (void)
    {
    if (kbd_getch (FALSE) == KEY_CTRL_C)
        {
        if (dia_yesno (txt_get (TXT_ASK_BREAK), 2) == YES)
            return (1);
        else
            return (0);
        }
    else
        return (0);
    }


void util_disp_init()
{
  int i_ii;

  config.win = 1;
  disp_set_display();
  if (config.utf8) printf("\033%%G");
  fflush(stdout);
  if (config.linemode)
    return;
  for(i_ii = 1; i_ii < max_y_ig; i_ii++) printf("\n"); printf("\033[9;0]");
  disp_cursor_off();
  util_print_banner();
}


void util_disp_done()
{
  if (config.linemode) {
    printf("\n\n");
    config.win = 0;
    return;
  }
  disp_clear_screen();
  printf("\033c");
  fflush(stdout);

  config.win = 0;
}


int util_umount(char *dir)
{
  int i;
  file_t *f0, *f;
  struct stat sbuf;

  if(!dir) return 0;

  if(stat(dir, &sbuf)) return -1;

  // fprintf(stderr, "umount: >%s<\n", dir);

  f0 = file_read_file("/proc/mounts", kf_none);

  if((i = umount(dir))) {
    // fprintf(stderr, "umount: %s: %s\n", dir, strerror(errno));
    if(errno != ENOENT && errno != EINVAL) {
      if(config.run_as_linuxrc) fprintf(stderr, "umount: %s: %s\n", dir, strerror(errno));
    }
  }

  if(!i) {
    for(f = f0; f; f = f->next) {
      if(
        strstr(f->key_str, "/dev/loop") == f->key_str &&
        strstr(f->value, dir) == f->value &&
        isspace(f->value[strlen(dir)])
      ) {
        util_detach_loop(f->key_str);
      }
    }
  }

  file_free_file(f0);

  if(config.mountpoint.base && strstr(dir, config.mountpoint.base) == dir) rmdir(dir);

  return i;
}


void util_umount_all()
{
  int i;
  char *buf = NULL;

  url_umount(config.url.instsys);
  sync(); /* umount seems to be racy; see bnc#443430 */
  url_umount(config.url.install);

  for(i = config.mountpoint.cnt; i-- > 0;) {
    strprintf(&buf, "%smp_%04u", config.mountpoint.base, i);
    if(util_check_exist(buf)) util_umount(buf);
  }

  str_copy(&buf, NULL);
}


int _util_eject_cdrom(char *dev)
{
  int fd;
  char buf[64];

  if(!dev) return 0;

  if(strstr(dev, "/dev/") != dev) {
    sprintf(buf, "/dev/%s", dev);
    dev = buf;
  }

  fprintf(stderr, "eject %s\n", dev);

  if((fd = open(dev, O_RDONLY | O_NONBLOCK)) < 0) return 1;
  util_umount(dev);
  if(ioctl(fd, CDROMEJECT, NULL) < 0) { close(fd); return 2; }
  close(fd);

  return 0;
}

int util_eject_cdrom(char *dev)
{
  slist_t *sl;

  if(dev) return _util_eject_cdrom(dev);
  util_update_cdrom_list();

  for(sl = config.cdroms; sl; sl = sl->next) {
    _util_eject_cdrom(sl->key);
  }

  return 0;
}


void add_driver_update(char *dir, char *loc)
{
  unsigned u;
  size_t len;
  char *copy_dir[] = { "install", "modules", "y2update", "inst-sys" };
  char *src = NULL, *dst = NULL, *buf1 = NULL, *buf2 = NULL;
  char *argv[3];
  struct dirent *de;
  DIR *d;
  FILE *f;
  file_t *ft0, *ft;
  slist_t *sl;
  unsigned prio;

  /* create destination, if missing */
  if(util_check_exist(config.update.dst) != 'd') {
    if(mkdir(config.update.dst, 0755)) return;
  }

  str_copy(&config.update.id, NULL);

  prio = config.update.count;

  /* preliminary config file read for update id & priority */
  strprintf(&buf1, "%s/dud.config", dir);
  ft0 = file_read_file(buf1, kf_cfg);
  for(ft = ft0; ft; ft = ft->next) {
    if(ft->key == key_updateid && *ft->value) {
      str_copy(&config.update.id, ft->value);
    }
    if(ft->key == key_updateprio && ft->is.numeric) {
      prio = ft->nvalue;
      if(prio > MAX_UPDATES - 100) prio = MAX_UPDATES - 100;
    }
  }
  file_free_file(ft0);
  free(buf1); buf1 = NULL;

  for(; prio < MAX_UPDATES; prio++) {
    if(!config.update.map[prio]) break;
  }

  if(prio >= MAX_UPDATES) {
    fprintf(stderr, "Error: Too many driver updates!!!\n");
    return;
  }

  if((sl = slist_getentry(config.update.id_list, config.update.id))) {
    fprintf(stderr, "dud: %s (duplicate of %s, skipped)\n", loc, sl->value);
    return;
  }

  config.update.map[prio] = 1;
  config.update.count++;

  strprintf(&dst, "%s/%03u", config.update.dst, prio);
  if(mkdir(dst, 0755)) return;

  fprintf(stderr, "dud %u: %s", prio, loc);
  if(config.update.id) {
    fprintf(stderr, " (id %s)", config.update.id);
  }
  fprintf(stderr, "\n");

  if(config.update.id) {
    sl = slist_append_str(&config.update.id_list, config.update.id);
    strprintf(&sl->value, "%u", prio);
  }

  /* copy directories */
  for(u = 0; u < sizeof copy_dir / sizeof *copy_dir; u++) {
    strprintf(&src, "%s/%s", dir, copy_dir[u]);
    if(util_check_exist(src) != 'd') continue;

    strprintf(&buf1, "%s/%s", dst, copy_dir[u]);

    if(util_check_exist(buf1) == 'd' || !mkdir(buf1, 0755)) {
      util_do_cp(src, buf1);
    }

    /* for compatibility */
    if(!strcmp(copy_dir[u], "y2update")) {
      strprintf(&buf1, "%s/%s", config.update.dst, copy_dir[u]);

      if(util_check_exist(buf1) == 'd' || !mkdir(buf1, 0755)) {
        util_do_cp(src, buf1);
      }
    }
  }

  /* copy config file */
  strprintf(&src, "%s/dud.config", dir);
  if(util_check_exist(src) == 'r') {
    argv[1] = src;
    argv[2] = dst;
    util_cp_main(3, argv);
  }

  /* make sure scripts are executable */
  strprintf(&buf1, "%s/install", dst);
  if((d = opendir(buf1))) {
    while((de = readdir(d))) {
      if(strstr(de->d_name, "update.") == de->d_name) {
        strprintf(&buf2, "%s/%s", buf1, de->d_name);
        chmod(buf2, 0755);
      }
    }
    closedir(d);
  }

  /* module things: save order to "module.order" */
  strprintf(&buf1, "%s/modules", dir);
  if(util_check_exist(buf1) == 'd') {
    if((d = opendir(buf1))) {
      strprintf(&buf2, "%s/modules/module.order", dst);
      if(!util_check_exist(buf2) && (f = fopen(buf2, "w"))) {
        while((de = readdir(d))) {
          if(
            (len = strlen(de->d_name)) > sizeof MODULE_SUFFIX - 1 &&
            !strcmp(de->d_name + len - (sizeof MODULE_SUFFIX - 1), MODULE_SUFFIX)
          ) {
            fprintf(f, "%s\n", de->d_name);
          }
        }
        fclose(f);
      }
      closedir(d);
    }
  }

  free(src);
  free(dst);
  free(buf1);
  free(buf2);
}


int cmp_dir_entry(slist_t *sl0, slist_t *sl1)
{
  int i0, i1;

  i0 = strtol(sl0->key, NULL, 10);
  i1 = strtol(sl1->key, NULL, 10);

  return i0 - i1;
}


/* wrapper for qsort */
int cmp_dir_entry_s(const void *p0, const void *p1)
{
  slist_t **sl0, **sl1;

  sl0 = (slist_t **) p0;
  sl1 = (slist_t **) p1;

  return cmp_dir_entry(*sl0, *sl1);
}


/*
 * Check for a valid driver update directory below <dir>; copy the files
 * to /update.
 *
 * Note: you must call util_do_driver_updates() to actuall apply
 * the update.
 */
int util_chk_driver_update(char *dir, char *loc)
{
  char *drv_src = NULL, *dud_loc = NULL, *s;
  slist_t *sl0 = NULL, *sl;
  struct dirent *de;
  DIR *d;
  int is_update = 0;

  if(!dir || !loc || !config.tmpfs || !config.update.dir) return is_update;

  strprintf(&drv_src, "%s%s", dir, config.update.dir);

  if(util_check_exist(drv_src) == 'd') {
    strprintf(&dud_loc, "%s:%s", loc, config.update.dir);
    is_update = 1;
    add_driver_update(drv_src, dud_loc);
  }

  d = opendir(dir);
  if(d) {
    while((de = readdir(d))) {
      strtol(de->d_name, &s, 10);
      if(!*s) {
        strprintf(&drv_src, "%s/%s%s", dir, de->d_name, config.update.dir);
        if(util_check_exist(drv_src) == 'd') {
          is_update = 1;
          slist_append_str(&sl0, de->d_name);
        }
      }
    }
    closedir(d);
  }

  sl0 = slist_sort(sl0, cmp_dir_entry_s);

  for(sl = sl0; sl; sl = sl->next) {
    strprintf(&drv_src, "%s/%s%s", dir, sl->key, config.update.dir);
    strprintf(&dud_loc, "%s:/%s%s", loc, sl->key, config.update.dir);
    add_driver_update(drv_src, dud_loc);
  }

  free(drv_src);
  free(dud_loc);

  return is_update;
}


void util_do_driver_update(unsigned idx)
{
  char *s, *buf1 = NULL, *buf2 = NULL, *dst = NULL;
  file_t *f0, *f;
  slist_t *sl;

  strprintf(&dst, "%s/%03u", config.update.dst, idx);

  /* read config file */
  config.update.name_added = 0;
  strprintf(&buf1, "file:/%s/dud.config", dst);
  file_read_info_file(buf1, kf_cfg);

  if(!config.update.name_added) create_update_name(idx);

  /* write update name, if there is one */
  fprintf(stderr, "dud %u:\n", idx);
  for(
    ;
    (sl = *config.update.next_name);
    config.update.next_name = &(*config.update.next_name)->next
  ) {
    fprintf(stderr, "  %s\n", sl->key);
    if(!config.win) {
      if(config.linebreak) {
        printf("\n");
        config.linebreak = 0;
      }
      printf("Driver Update: %s\n", sl->key);
    }
  }

  /* read new driver data */
  strprintf(&buf1, "%s/modules/hd.ids", dst);
  if(util_check_exist(buf1) == 'r') {
    strprintf(&buf2,
      "cat %s %s >/var/lib/hardware/tmp.ids",
      buf1,
      util_check_exist("/var/lib/hardware/hd.ids") ? "/var/lib/hardware/hd.ids" : ""
    );
    system(buf2);
    rename("/var/lib/hardware/tmp.ids", "/var/lib/hardware/hd.ids");
  }

  /* link new modules */
  strprintf(&buf1, "%s/modules/module.order", dst);
  f0 = file_read_file(buf1, kf_none);
  for(f = f0; f; f = f->next) {
    strprintf(&buf1, "%s/modules/%s", dst, f->key_str);
    strprintf(&buf2, "/modules/%s", f->key_str);
    unlink(buf2);
    symlink(buf1, buf2);
  }

  /* load new modules */
  strprintf(&buf1, "%s/modules/module.config", dst);
  if(util_check_exist(buf1) == 'r') {
    strprintf(&buf2, "cp %s/modules/module.config /modules", dst);
    system(buf2);
    mod_init(1);
  }
  else {
    str_copy(&buf1, "");
    for(f = f0; f; f = f->next) {
      if((s = strrchr(f->key_str, '.'))) *s = 0;
      strprintf(&buf1, "%s %s", buf1, f->key_str);
    }
    if(*buf1) mod_unload_modules(buf1);
    for(f = f0; f; f = f->next) {
      mod_modprobe(f->key_str, NULL);
    }
  }

  file_free_file(f0);
  free(dst);
  free(buf1);
  free(buf2);

}


/*
 * In case the update description is missing, create it using module names.
 */
void create_update_name(unsigned idx)
{
  char *buf1 = NULL, *mod;
  file_t *f0, *f;
  size_t len;
  module_t *ml;

  strprintf(&buf1, "%s/%03u/modules/module.order", config.update.dst, idx);
  f0 = file_read_file(buf1, kf_none);
  for(f = f0; f; f = f->next) {
    len = strlen(mod = f->key_str);
    if(len > 2 && !strcmp(mod + len - 2, ".o")) {
      mod[len - 2] = 0;
      ml = mod_get_entry(mod);
      if(ml && ml->descr && *ml->descr) mod = ml->descr;
      slist_append_str(&config.update.name_list, mod);
    }
  }

  file_free_file(f0);
  free(buf1);

}


/*
 * Apply all new driver updates.
 */
void util_do_driver_updates()
{
  unsigned u;

  if(!config.tmpfs) return;

  for(u = 0; u < MAX_UPDATES; u++) {
    if(config.update.map[u] == 1) {
      util_do_driver_update(u);
      config.update.map[u] = 2;
    }
  }
}


int show_driver_updates()
{

  if(config.update.name_list) {
    dia_show_lines2(txt_get(TXT_DUD_LIST), config.update.name_list, 64);
  }
  else {
    dia_message(txt_get(TXT_DUD_NOT_YET), MSGTYPE_INFO);
  }

  return 0;
}


void add_flag(slist_t **sl, char *buf, int value, char *name)
{
  int l;

  if(value <= 0) return;

  if(!*buf) strcpy(buf, "  ");
  l = strlen(buf);

  sprintf(buf + strlen(buf), "%s%s", buf[l - 1] == ' ' ? "" : ", ", name);

  if(strlen(buf) > 40) {
    slist_append_str(sl, buf);
    *buf = 0;
  }
}


void util_status_info(int log_it)
{
  int i, j;
  char *s, *t;
  hd_data_t *hd_data;
  slist_t *sl, *sl0 = NULL;
  char buf[256];
  language_t *lang;
  driver_t *drv;

  hd_data = calloc(1, sizeof *hd_data);
  hd_data->debug = 1;
  hd_scan(hd_data);

  if(hd_data->log) {
    s = strchr(hd_data->log, '\n');
    if(s) {
      *s = 0;
      slist_append_str(&sl0, hd_data->log);
    }
  }

  sprintf(buf, "product = \"%s\"", config.product);
  slist_append_str(&sl0, buf);

  sprintf(buf,
    "memory (kB): total %d, free %d (%d), ramdisk %d",
    config.memory.total, config.memory.current,
    config.memory.current - config.memory.free_swap,
    config.memory.free - config.memory.current
  );
  slist_append_str(&sl0, buf);

  sprintf(buf,
    "memory limits: min %d, yast %d, image %d",
    config.memory.min_free, config.memory.min_yast, config.memory.load_image
  );
  slist_append_str(&sl0, buf);

  util_get_ram_size();

  sprintf(buf,
    "RAM size (MB): total %u, min %u",
    config.memory.ram, config.memory.ram_min
  );
  slist_append_str(&sl0, buf);

  sprintf(buf, "swap file size: %u MB", config.swap_file_size);
  slist_append_str(&sl0, buf);

  sprintf(buf,
    "InstsysID: %s%s",
    config.instsys_id ?: "unset",
    config.instsys_complain ? config.instsys_complain == 1 ? " (check)" : " (block)" : ""
  );
  slist_append_str(&sl0, buf);

  sprintf(buf, "InitrdID: %s", config.initrd_id ?: "unset");
  slist_append_str(&sl0, buf);

  for(sl = config.update.expected_name_list; sl; sl = sl->next) {
    sprintf(buf, "expected update: %s", sl->key);
    slist_append_str(&sl0, buf);
  }

  sprintf(buf, "flags = ");
  add_flag(&sl0, buf, config.debug, "debug");
  add_flag(&sl0, buf, config.test, "test");
  add_flag(&sl0, buf, config.tmpfs, "tmpfs");
  add_flag(&sl0, buf, config.manual, "manual");
  add_flag(&sl0, buf, config.rescue, "rescue");
  add_flag(&sl0, buf, config.vnc, "vnc");
  add_flag(&sl0, buf, config.usessh, "usessh");
  add_flag(&sl0, buf, config.textmode, "textmode");
  add_flag(&sl0, buf, config.rebootmsg, "rebootmsg");
  add_flag(&sl0, buf, config.nopcmcia, "nopcmcia");
  add_flag(&sl0, buf, config.net.use_dhcp, "dhcp");
  add_flag(&sl0, buf, config.net.dhcp_active, "dhcp_active");
  add_flag(&sl0, buf, config.use_ramdisk, "ramdisk");
  add_flag(&sl0, buf, config.ask_language, "ask_lang");
  add_flag(&sl0, buf, config.ask_keytable, "ask_keytbl");
  add_flag(&sl0, buf, config.addswap, "addswap");
  add_flag(&sl0, buf, config.splash, "splash");
  add_flag(&sl0, buf, config.noshell, "noshell");
  add_flag(&sl0, buf, config.had_segv, "segv");
  add_flag(&sl0, buf, config.scsi_before_usb, "scsibeforeusb");
  add_flag(&sl0, buf, config.scsi_rename, "scsirename");
  add_flag(&sl0, buf, config.has_pcmcia, "pcmcia");
  add_flag(&sl0, buf, config.net.all_ifs, "all_ifs");
  add_flag(&sl0, buf, config.ntfs_3g, "ntfs-3g");
  add_flag(&sl0, buf, config.secure, "secure");
  add_flag(&sl0, buf, config.mediacheck, "mediacheck");
  add_flag(&sl0, buf, config.net.ipv4, "ipv4");
  add_flag(&sl0, buf, config.net.ipv6, "ipv6");
  add_flag(&sl0, buf, config.efi, "efi");
  add_flag(&sl0, buf, config.efi_vars, "efivars");
  add_flag(&sl0, buf, config.staticdevices ^ 1, "udev");
  add_flag(&sl0, buf, config.udev_mods, "udev.mods");
  if(*buf) slist_append_str(&sl0, buf);

  sprintf(buf, "net_config_mask = 0x%x", net_config_mask());
  slist_append_str(&sl0, buf);

  sprintf(buf, "netsetup = 0x%x/0x%x", config.net.do_setup, config.net.setup);
  slist_append_str(&sl0, buf);

  if((s = url_print(config.url.install, 0))) {
    slist_append_str(&sl0, "install url:");
    sprintf(buf, "  %s", s);
    slist_append_str(&sl0, buf);
  }

  if((s = url_print(config.url.instsys, 0))) {
    slist_append_str(&sl0, "instsys url:");
    sprintf(buf, "  %s", s);
    slist_append_str(&sl0, buf);
  }

  if((s = url_print(config.url.proxy, 0))) {
    slist_append_str(&sl0, "proxy url:");
    sprintf(buf, "  %s", s);
    slist_append_str(&sl0, buf);
  }

  if(config.autoyast) {
    sprintf(buf, "autoyast = %s", config.autoyast);
    slist_append_str(&sl0, buf);
  }

  strcpy(buf, "net devices = (");
  for(i = 0, sl = config.net.devices; sl; sl = sl->next) {
    if(!sl->key) continue;
    j = !config.net.device || strcmp(sl->key, config.net.device) ? 0 : 1;
    sprintf(buf + strlen(buf), "%s%s%s", i ? ", " : " ", sl->key, j ? "*" : "");
    if(sl->value) sprintf(buf + strlen(buf), " [%s]", sl->value);
    i = 1;
  }
  strcat(buf, " )");
  slist_append_str(&sl0, buf);

  if(config.cdid) {
    sprintf(buf, "cdrom id = %s", config.cdid);
    slist_append_str(&sl0, buf);
  }

  sprintf(buf, "hostname = %s", inet2print(&config.net.hostname));
  slist_append_str(&sl0, buf);

  sprintf(buf, "domain = %s", config.net.domain ?: "");
  slist_append_str(&sl0, buf);

  sprintf(buf, "network = %s", inet2print(&config.net.network));
  slist_append_str(&sl0, buf);

  sprintf(buf, "netmask = %s", inet2print(&config.net.netmask));
  slist_append_str(&sl0, buf);

  sprintf(buf, "broadcast = %s", inet2print(&config.net.broadcast));
  slist_append_str(&sl0, buf);

  sprintf(buf, "gateway = %s", inet2print(&config.net.gateway));
  slist_append_str(&sl0, buf);

  for(i = 0; i < config.net.nameservers; i++) {
    sprintf(buf, "nameserver%d = %s", i + 1, inet2print(&config.net.nameserver[i]));
    slist_append_str(&sl0, buf);
  }

  sprintf(buf, "ptp host = %s", inet2print(&config.net.ptphost));
  slist_append_str(&sl0, buf);

  if(config.net.vncpassword) {
    sprintf(buf, "vncpassword = %s", config.net.vncpassword);
    slist_append_str(&sl0, buf);
  }

  if(config.net.sshpassword) {
    sprintf(buf, "sshpassword = %s", config.net.sshpassword);
    slist_append_str(&sl0, buf);
  }

  if(config.net.wlan.auth) {
    static char *wlan_a[] = { "", "open", "wep open", "wep restricted", "wpa" };
    sprintf(buf, "wlan auth = %d (%s)",
      config.net.wlan.auth,
      wlan_a[config.net.wlan.auth < sizeof wlan_a / sizeof *wlan_a ? config.net.wlan.auth : 0]
    );
    slist_append_str(&sl0, buf);
  }

  if(config.net.wlan.essid) {
    sprintf(buf, "wlan essid = \"%s\"", config.net.wlan.essid);
    slist_append_str(&sl0, buf);
  }

  if(config.net.wlan.key) {
    sprintf(buf, "wlan key = \"%s\", type %d",
      config.net.wlan.key,
      config.net.wlan.key_type
    );
    if(config.net.wlan.key_len) {
      sprintf(buf + strlen(buf), ", len %d)", config.net.wlan.key_len);
    }
    slist_append_str(&sl0, buf);
  }

  if(config.net.use_dhcp) {
    s = "", t = "*";
  }
  else {
    s = "*", t = "";
  }
  sprintf(buf,
    "timeouts: bootp%s = %ds, dhcp%s = %ds, tftp = %ds",
    s, config.net.bootp_timeout, t, config.net.dhcp_timeout, config.net.tftp_timeout
  );
  slist_append_str(&sl0, buf);

  if(config.net.retry) {
    sprintf(buf, "max connection retries: %d", config.net.retry);
    slist_append_str(&sl0, buf);
  }

  if(config.net.bootp_wait) {
    sprintf(buf, "bootp wait = %d", config.net.bootp_wait);
    slist_append_str(&sl0, buf);
  }

  if(config.rootpassword) {
    sprintf(buf, "rootpassword = %s", config.rootpassword);
    slist_append_str(&sl0, buf);
  }

  if(config.net.ifup_wait) {
    sprintf(buf, "net config wait = %ds", config.net.ifup_wait);
    slist_append_str(&sl0, buf);
  }

  lang = current_language();

  sprintf(buf, "language = %s, keymap = %s", lang->locale, config.keymap ?: "");
  slist_append_str(&sl0, buf);

  sprintf(buf,
    "dud = %d, updates = %d, dir = \"%s\"",
    config.update.ask, config.update.count, config.update.dir
  );
  slist_append_str(&sl0, buf);

  if(config.term) {
    sprintf(buf, "term = \"%s\"", config.term);
    slist_append_str(&sl0, buf);
  }

  sprintf(buf, "console = \"%s\"", config.console);
  if(config.serial) sprintf(buf + strlen(buf), ", serial line params = \"%s\"", config.serial);
  slist_append_str(&sl0, buf);
  sprintf(buf, "esc delay: %dms", config.escdelay);
  slist_append_str(&sl0, buf);


  sprintf(buf, "stderr = \"%s\"", config.stderr_name);
  slist_append_str(&sl0, buf);

  sprintf(buf, "rootimage = \"%s\"", config.rootimage);
  slist_append_str(&sl0, buf);

  if(config.rootimage2) {
    sprintf(buf, "rootimage2 = \"%s\"", config.rootimage2);
    slist_append_str(&sl0, buf);
  }

  sprintf(buf, "rescueimage = \"%s\"", config.rescueimage);
  slist_append_str(&sl0, buf);

  sprintf(buf, "setup command = \"%s\"", config.setupcmd);
  slist_append_str(&sl0, buf);

  if(config.module.broken) {
    strcpy(buf, "broken modules:");
    slist_append_str(&sl0, buf);
    for(sl = config.module.broken; sl; sl = sl->next) {
      if(!sl->key) continue;
      sprintf(buf, "  %s", sl->key);
      slist_append_str(&sl0, buf);
    }
  }

  if(config.module.initrd) {
    strcpy(buf, "extra initrd modules:");
    slist_append_str(&sl0, buf);
    for(sl = config.module.initrd; sl; sl = sl->next) {
      if(!sl->key) continue;
      sprintf(buf, "  %s", sl->key);
      slist_append_str(&sl0, buf);
    }
  }

  if(config.ethtool) {
    strcpy(buf, "ethtool options:");
    slist_append_str(&sl0, buf);
    for(sl = config.ethtool; sl; sl = sl->next) {
      sprintf(buf, "  %s: %s", sl->key, sl->value);
      slist_append_str(&sl0, buf);
    }
  }

  if(config.cdroms) {
    strcpy(buf, "cdroms:");
    slist_append_str(&sl0, buf);
    for(sl = config.cdroms; sl; sl = sl->next) {
      if(!sl->key) continue;
      i = config.cdrom && !strcmp(sl->key, config.cdrom) ? 1 : 0;
      sprintf(buf, "  %s%s", sl->key, i ? "*" : "");
      if(sl->value) sprintf(buf + strlen(buf), " [%s]", sl->value);
      slist_append_str(&sl0, buf);
    }
  }

  if(config.disks) {
    strcpy(buf, "disks:");
    slist_append_str(&sl0, buf);
    for(sl = config.disks; sl; sl = sl->next) {
      if(!sl->key) continue;
      sprintf(buf, "  %s", sl->key);
      if(sl->value) sprintf(buf + strlen(buf), " [%s]", sl->value);
      slist_append_str(&sl0, buf);
    }
  }

  if(config.partitions) {
    strcpy(buf, "partitions:");
    slist_append_str(&sl0, buf);
    for(sl = config.partitions; sl; sl = sl->next) {
      if(!sl->key) continue;
      i = config.device && !strcmp(sl->key, config.device) ? 1 : 0;
      sprintf(buf, "  %s%s", sl->key, i ? "*" : "");
      if(sl->value) sprintf(buf + strlen(buf), " [%s]", sl->value);
      slist_append_str(&sl0, buf);
    }
  }

  if(config.module.drivers) {
    strcpy(buf, "new driver info (v d sv sd c cm, module, sysfs, usage):");
    slist_append_str(&sl0, buf);
    for(drv = config.module.drivers; drv; drv = drv->next) {
      sprintf(buf, "  %s, %s, %s, %u",   
        print_driverid(drv, 1),
        drv->name ?: "",
        drv->sysfs_name ?: "",
        drv->used
      );
      slist_append_str(&sl0, buf);
    }
  }

  if(config.sha1) {
    strcpy(buf, "sha1 sums:");
    slist_append_str(&sl0, buf);
    for(sl = config.sha1; sl; sl = sl->next) {
      sprintf(buf, "  %s %s", sl->key, sl->value);
      slist_append_str(&sl0, buf);
    }
  }

  if(config.ptoptions) {
    strcpy(buf, "user defined options:");
    slist_append_str(&sl0, buf);
    for(sl = config.ptoptions; sl; sl = sl->next) {
      sprintf(buf, "  %s: %s", sl->key, sl->value ?: "<unset>");
      slist_append_str(&sl0, buf);
    }
  }

  if(config.module.options) {
    strcpy(buf, "module options:");
    slist_append_str(&sl0, buf);
    for(sl = config.module.options; sl; sl = sl->next) {
      sprintf(buf, "  %s: %s", sl->key, sl->value);
      slist_append_str(&sl0, buf);
    }
  }

  if(log_it || config.debug >= 1) {
    fprintf(stderr, "------  Linuxrc v" LXRC_FULL_VERSION " (" __DATE__ ", " __TIME__ ")  ------\n");
    for(sl = sl0; sl; sl = sl->next) {
      fprintf(stderr, "  %s\n", sl->key);
    }
    fprintf(stderr, "------  ------\n");
  }

  if(!log_it) {
    dia_show_lines2("Linuxrc v" LXRC_FULL_VERSION " (" __DATE__ ", " __TIME__ ")", sl0, 76);
  }

  slist_free(sl0);

  hd_free_hd_data(hd_data);
  free(hd_data);
}

void util_get_splash_status()
{
  FILE *f;
  char s[80];

  config.splash = 0;

  if((f = fopen("/proc/splash", "r"))) {
    if(fgets(s, sizeof s, f)) {
      if(strstr(s, ": on")) config.splash = 1;
      setenv("SPLASHCFG", "/etc/splash.cfg", 1);
    }
    fclose(f);
  }
}


/*
 * Set splash progress bar to num percent.
 */
void util_splash_bar(unsigned num, char *trigger)
{
  static unsigned old = 0;
  char buf[256], buf2[256];

  if(!config.splash) return;

  if(num > 100) num = 100;

  num = (num * 65535) / 100;

  if(num < old) old = num;

  *buf2 = 0;
  if(trigger) sprintf(buf2, "-t '%s'", trigger);

  sprintf(buf, "/sbin/splash -p %u:%d %s", old, num - old, buf2);
  system(buf);

  old = num;
}


char *read_symlink(char *file)
{
  static char buf[256];
  int i;

  i = readlink(file, buf, sizeof buf);
  buf[sizeof buf - 1] = 0;
  if(i >= 0 && (unsigned) i < sizeof buf) buf[i] = 0;
  if(i < 0) *buf = 0;

  return buf;
}


void show_lsof_info(FILE *f, unsigned pid)
{
  char pe[128];
  char buf1[64], buf2[128], buf3[256];
  FILE *p;
  DIR *dir;
  struct dirent *de;
  unsigned status = 0;
  char *s, c;
  struct stat sbuf;
  file_t *f0, *f1;
  slist_t *sl0 = NULL, *sl;

  sprintf(pe, "/proc/%u/status", pid);
  if((p = fopen(pe, "r"))) {
    if(fscanf(p, "Name: %63[^\n]", buf1) == 1) status = 1;
    fclose(p);
  }

  if(!status) *buf1 = 0;

  sprintf(buf2, "%-9s %5u ", buf1, pid);

  sprintf(pe, "/proc/%u/cwd", pid);
  if(*(s = read_symlink(pe))) fprintf(f, "%s cwd  %s\n", buf2, s);

  sprintf(pe, "/proc/%u/root", pid);
  if(*(s = read_symlink(pe))) fprintf(f, "%s rtd  %s\n", buf2, s);

  sprintf(pe, "/proc/%u/exe", pid);
  if(*(s = read_symlink(pe))) fprintf(f, "%s txt  %s\n", buf2, s);

  sprintf(pe, "/proc/%u/fd", pid);
  if((dir = opendir(pe))) {
    while((de = readdir(dir))) {
      if(*de->d_name != '.') {
        sprintf(pe, "/proc/%u/fd/%s", pid, de->d_name);
        if(*(s = read_symlink(pe))) {
          c = ' ';
          if(!lstat(pe, &sbuf)) {
            if((sbuf.st_mode & S_IRUSR)) c = 'r';
            if((sbuf.st_mode & S_IWUSR)) c = c == 'r' ? 'u' : 'w';
          }
          fprintf(f, "%s %3s%c %s\n", buf2, de->d_name, c, s);
        }
      }
    }
    closedir(dir);
  }

  sprintf(pe, "/proc/%u/maps", pid);
  f0 = file_read_file(pe, kf_none);

  for(f1 = f0; f1; f1 = f1->next) {
    *buf3 = 0;
    if(sscanf(f1->value, "%*s %*s %*s %*s %255[^\n]", buf3)) {
      if(*buf3 && !slist_getentry(sl0, buf3)) {
        sl = slist_append(&sl0, slist_new());
        sl->key = strdup(buf3);
      }
    }
  }

  file_free_file(f0);

  for(sl = sl0; sl; sl = sl->next) {
    fprintf(f, "%s mem  %s\n", buf2, sl->key);
  }

  slist_free(sl0);
}

char *util_process_cmdline(pid_t pid)
{
  char pe[100];
  static char buf[256];
  FILE *p;
  unsigned status = 0;
  unsigned u, v;

  sprintf(pe, "/proc/%u/cmdline", pid);
  if((p = fopen(pe, "r"))) {
    u = fread(buf, 1, sizeof buf, p);
    if(u > sizeof buf - 1) u = sizeof buf - 1;
    for(v = 0; v < u; v++) if(!buf[v]) buf[v] = ' ';
    buf[u] = 0;
    status = 1;
    fclose(p);
  }

  if(!status) *buf = 0;

  return buf;
}

void show_ps_info(FILE *f, unsigned pid)
{
  char pe[100];
  char buf1[64], buf2[2], *buf3;
  FILE *p;
  unsigned status = 0;

  sprintf(pe, "/proc/%u/status", pid);
  if((p = fopen(pe, "r"))) {
    if(fscanf(p, "Name: %63[^\n]", buf1) == 1) status |= 1;
    if(fscanf(p, "\nState: %1s", buf2) == 1) status |= 2;
    fclose(p);
  }

  buf3 = util_process_cmdline(pid);

  if(!(status & 1)) *buf1 = 0;
  if(!(status & 2)) *buf2 = 0;

  fprintf(f, "%5u %s %-16s %s\n", pid, buf2, buf1, buf3);
}

int util_do_cp(char *src, char *dst)
{
  int i;

  exclude = strrchr(dst, '/');
  if(exclude) exclude++; else exclude = dst;
  rec_level = 0;

  i = do_cp(src, dst);
  free_hlink_list();

  return i;
}


/*
 * Copy recursively src to dst. Both must be existing directories.
 */
int do_cp(char *src, char *dst)
{
  DIR *dir;
  struct dirent *de;
  struct stat sbuf, sbuf2;
  char src2[0x100];
  char dst2[0x100];
  char *s;
  int i, j;
  int err = 0;
  unsigned char buf[0x1000];
  int fd1, fd2;
  struct utimbuf ubuf;

  if((dir = opendir(src))) {
    while((de = readdir(dir))) {
      if(!strcmp(de->d_name, ".") || !strcmp(de->d_name, "..")) continue;
      sprintf(src2, "%s/%s", src, de->d_name);
      sprintf(dst2, "%s/%s", dst, de->d_name);
      i = lstat(src2, &sbuf);
      if(i == -1) {
        perror(src2);
        err = 2;
        break;
      }

      if(S_ISDIR(sbuf.st_mode)) {
        // avoid infinite recursion
        if(exclude && !rec_level && !strcmp(exclude, de->d_name)) continue;

        i = stat(dst2, &sbuf2);
        if(i || !S_ISDIR(sbuf2.st_mode)) {
          unlink(dst2);
          i = mkdir(dst2, 0755);
          if(i) {
            err = 4;
            perror(dst2);
            break;
          }
        }

        rec_level++;
        err = do_cp(src2, dst2);
        rec_level--;

        if(err) break;
      }

      else if(S_ISREG(sbuf.st_mode)) {
        unlink(dst2);
        s = NULL;
        if(sbuf.st_nlink > 1) {
          s = walk_hlink_list(sbuf.st_ino, sbuf.st_dev, dst2);
        }

        if(s) {
          // just make a link

          i = link(s, dst2);
          if(i) {
            err = 12;
            perror(dst2);
            break;
          }
        }
        else {
          // actually copy it

          fd1 = open(src2, O_RDONLY);
          if(fd1 < 0) {
            err = 5;
            perror(src2);
            break;
          }
          fd2 = open(dst2, O_WRONLY | O_CREAT | O_TRUNC, 0644);
          if(fd2 < 0) {
            err = 6;
            perror(dst2);
            close(fd1);
            break;
          }
          do {
            i = read(fd1, buf, sizeof buf);
            j = 0;
            if(i > 0) {
              j = write(fd2, buf, i);
            }
          }
          while(i > 0 && j > 0);
          if(i < 0) {
            perror(src2);
            err = 7;
          }
          if(j < 0) {
            perror(dst2);
            err = 8;
          }
          close(fd1);
          close(fd2);
          if(err) break;
        }
      }

      else if(S_ISLNK(sbuf.st_mode)) {
        i = readlink(src2, buf, sizeof buf - 1);
        if(i < 0) {
          err = 9;
          perror(src2);
          break;
        }
        else {
          buf[i] = 0;
        }
        unlink(dst2);
        i = symlink(buf, dst2);
        if(i) {
          err = 10;
          perror(dst2);
          break;
        }
      }

      else if(
        S_ISCHR(sbuf.st_mode) ||
        S_ISBLK(sbuf.st_mode) ||
        S_ISFIFO(sbuf.st_mode) ||
        S_ISSOCK(sbuf.st_mode)
      ) {
        unlink(dst2);
        i = mknod(dst2, sbuf.st_mode, sbuf.st_rdev);
        if(i) {
          err = 11;
          perror(dst2);
          break;
        }
      }

      else {
        fprintf(stderr, "%s: type not supported\n", src2);
        err = 3;
        break;
      }

      // fix owner/time/permissions

      lchown(dst2, sbuf.st_uid, sbuf.st_gid);
      if(!S_ISLNK(sbuf.st_mode)) {
        chmod(dst2, sbuf.st_mode);
        ubuf.actime = sbuf.st_atime;
        ubuf.modtime = sbuf.st_mtime;
        utime(dst2, &ubuf);
      }

    }
  } else {
    perror(src);
    return 1;
  }

  closedir(dir);

  return err;
}


/*
 * Return either the file name belonging to dev/inode or, if
 * that's not found, return NULL and append dev/inode/dst to
 * the current list.
 */
char *walk_hlink_list(ino_t ino, dev_t dev, char *dst)
{
  struct hlink_s **hl;

  for(hl = &hlink_list; *hl; hl = &(*hl)->next) {
    if((*hl)->dev == dev && (*hl)->ino == ino) {
      return (*hl)->dst;
    }
  }

  *hl = calloc(1, sizeof **hl);

  (*hl)->dev = dev;
  (*hl)->ino = ino;
  (*hl)->dst = strdup(dst);

  return NULL;
}


void free_hlink_list()
{
  struct hlink_s *hl, *next;

  for(hl = hlink_list; hl; hl = next) {
    next = hl->next;
    if(hl->dst) free(hl->dst);
    free(hl);
  }

  hlink_list = NULL;
}


/*
 * flags:
 *   bit 0: 0 = keep env, 1 = set new env
 *   bit 1: 1 = login shell ("-l")
 */
void util_start_shell(char *tty, char *shell, int flags)
{
  int fd, i;
  FILE *f;
  char *s, *args[] = { NULL, NULL, NULL };
  char *env[] = {
    NULL, /* TERM */
    "LANG=en_US.UTF-8",
    "PS1=\\w # ",
    "HOME=/",
    "PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/X11R6/bin:/usr/local/bin:/lbin",
    NULL
  };
  extern char **environ;

  *args = (s = strrchr(shell, '/')) ? s + 1 : shell;

  if((flags & 2)) args[1] = "-l";

  strprintf(env + 0, "TERM=%s", getenv("TERM") ?: "linux");

  if(!fork()) {
    for(fd = 0; fd < 20; fd++) close(fd);
    setsid();
    fd = open(tty, O_RDWR);
    ioctl(fd, TIOCSCTTY, (void *) 1);
    dup(fd);
    dup(fd);

    printf("\033c");

    if(config.utf8) {
      printf("\033%%G");
      fflush(stdout);
    }

    if((f = fopen("/etc/motd", "r"))) {
      while((i = fgetc(f)) != EOF) putchar(i);
      fclose(f);
    }

    execve(shell, args, (flags & 1) ? env : environ);
    fprintf(stderr, "Couldn't start shell (errno = %d)\n", errno);
    exit(-1);
  }
}


int util_ps_main(int argc, char **argv)
{
  DIR *proc;
  struct dirent *de;
  unsigned u;
  char *s;

  if((proc = opendir("/proc"))) {
    while((de = readdir(proc))) {
      if(de->d_name) {
        u = strtoul(de->d_name, &s, 10);
        if(!*s) show_ps_info(stdout, u);
      }
    }
    closedir(proc);
  }

  return 0;
}


int util_lsof_main(int argc, char **argv)
{
  DIR *proc;
  struct dirent *de;
  unsigned u;
  char *s;

  if((proc = opendir("/proc"))) {
    while((de = readdir(proc))) {
      if(de->d_name) {
        u = strtoul(de->d_name, &s, 10);
        if(!*s) show_lsof_info(stdout, u);
      }
    }
    closedir(proc);
  }

  return 0;
}


int util_mount_main(int argc, char **argv)
{
  int i, notype = 0;
  char *dir, *srv_dir;
  char *type = NULL, *dev, *module;
  inet_t inet = {};
  unsigned long flags = 0;

  argv++; argc--;

  if(!argc) {
    return system("cat /proc/mounts");
  }

  if(argc < 2) return fprintf(stderr, "mount: invalid number of arguments\n"), 1;

  if(!strcmp(*argv, "-r")) {
    flags = MS_RDONLY;
    argv++;
    argc--;
  }

  if(strstr(*argv, "-t") == *argv) {
    type = *argv + 2;

    if(!*type) {
      type = *++argv;
      argc--;
    }

    argv++;
    argc--;
  }

  if(argc != 2) return fprintf(stderr, "mount: invalid number of arguments\n"), 1;

  dev = strcmp(*argv, "none") ? *argv : NULL;

  dir = argv[1];

  if(!type) {
    if(strchr(dev, ':')) {
      type = "nfs";
    }
    else {
      notype = 1;
      type = util_fstype(dev, &module);
      if(module) {
        return fprintf(stderr, "mount: fs type not supported, load module \"%s\" first\n", module), 2;
      }
    }
    // if(!type) return fprintf(stderr, "mount: no fs type given\n"), 2;
  }

  if(notype) {
    if(!util_mount(dev, dir, flags, NULL)) return 0;
    if(errno) perror("mount");
    return 1;
  }

  if(strcmp(type, "nfs")) {
    if(!mount(dev, dir, type, flags, 0)) return 0;
    if(errno) perror("mount");
    return 1;
  }

  srv_dir = strchr(dev, ':');
  if(!srv_dir) return fprintf(stderr, "mount: directory to mount not in host:dir format\n"), 1;

  *srv_dir++ = 0;

  str_copy(&inet.name, dev);
  i = net_mount_nfs(dir, &inet, srv_dir, 0);

  if(i && errno) {
    i = errno;
    perror("mount");
  }

  return i;
}


int util_umount_main(int argc, char **argv)
{
  int force = 0;
  int i;

  argv++; argc--;

  if(argc == 2 && !strcmp(*argv, "-f")) {
    force = 1;
    argv++;
    argc--;
  }

  if(argc != 1) fprintf(stderr, "u%s", "mount: invalid number of arguments\n"), 1;

  i = force ? umount2(*argv, MNT_FORCE) : util_umount(*argv);

  if(!i) return 0;

  fprintf(stderr, "umount: "); perror(*argv);

  return errno;
}


int util_cat_main(int argc, char **argv)
{
  FILE *f;
  int i, c;

  argv++; argc--;

  if(!argc) {
    while((c = fgetc(stdin)) != EOF) fputc(c, stdout);
    fflush(stdout);
    return 0;
  }

  for(i = 0; i < argc; i++) {
    if((f = fopen(argv[i], "r"))) {
      while((c = fgetc(f)) != EOF) fputc(c, stdout);
      fclose(f);
    }
    else {
      perror(argv[i]);
      return 1;
    }
  }

  fflush(stdout);

  return 0;
}


int util_hex_main(int argc, char **argv)
{
  FILE *f;
  int i, j = 0;
  char s[17];

  if(argc > 1) {
    f = fopen(argv[1], "r");
    if(!f) {
      perror(argv[1]);
      return errno;
    }
  }
  else {
    f = stdin;
  }

  s[16] = 0;
  while((i = fgetc(f)) != EOF) {
    i = i & 0xff;
    s[j & 15] = (i >= 0x20 && i <= 0x7e) ? i : '.';
    if(!(j & 15)) {
      printf("%06x  ", j);
    }
    if(!(j & 7) && (j & 15)) printf(" ");
    printf("%02x ", (int) i);
    if(!(++j & 15)) {
      printf(" %s\n", s);
    }
  }

  if(j & 15) {
    s[j & 15] = 0;
    if(!(j & 8)) printf(" ");
    printf("%*s %s\n", 3 * (16 - (j & 15)), "", s);
  }

  fflush(stdout);

  return 0;
}


int util_echo_main(int argc, char **argv)
{
  int i;

  argv++; argc--;

  for(i = 0; i < argc; i++) {
    printf("%s%s", i ? " " : "", argv[i]);
  }

  printf("\n");

  return 0;
}


int util_nothing_main(int argc, char **argv)
{
  return 0;
}


int util_cp_main(int argc, char **argv)
{
  int err = 0, rec = 0, preserve = 0;
  char *src, *dst, *s;
  char dst2[0x100];
  int i, j, fd1, fd2;
  unsigned char buf[0x1000];
  struct stat sbuf;
  struct utimbuf ubuf;

  argv++; argc--;

  while(argc) {
    if(argc >= 1 && !strcmp(*argv, "-a")) {
      argv++; argc--;
      rec = 1;
      continue;
    }

    if(argc >= 1 && !strcmp(*argv, "-p")) {
      argv++; argc--;
      preserve = 1;
      continue;
    }
    break;
  }

  if(argc != 2) return 1;

  src = argv[0];
  dst = argv[1];

  if(rec) {
    if(!util_check_exist(dst)) mkdir(dst, 0755);
    err = util_do_cp(src, dst);
  }
  else {
    i = stat(dst, &sbuf);
    if(!i && S_ISDIR(sbuf.st_mode)) {
      s = strrchr(src, '/');
      s = s ? s + 1 : src;
      sprintf(dst2, "%s/%s", dst, s);
      dst = dst2;
    }
    
    fd1 = open(src, O_RDONLY);
    if(fd1 < 0) {
      err = 1;
      perror(src);
    }
    else {
      unlink(dst);
      fd2 = open(dst, O_WRONLY | O_CREAT | O_TRUNC, 0644);
      if(fd2 < 0) {
        err = 2;
        perror(dst);
        close(fd1);
      }
      else {
        do {
          i = read(fd1, buf, sizeof buf);
          j = 0;
          if(i > 0) {
            j = write(fd2, buf, i);
          }
        }
        while(i > 0 && j > 0);
        if(i < 0) {
          perror(src);
          err = 3;
        }
        if(j < 0) {
          perror(dst);
          err = 4;
        }
        close(fd1);
        close(fd2);
      }
    }

    if(!err) {
      i = stat(src, &sbuf);
      if(!i) {
        chmod(dst, sbuf.st_mode);
        if(preserve) {
          chown(dst, sbuf.st_uid, sbuf.st_gid);
          ubuf.actime = sbuf.st_atime;
          ubuf.modtime = sbuf.st_mtime;
          utime(dst, &ubuf);
        }
      }
    }
  }

  return err;
}


int util_ls_main(int argc, char **argv)
{
  int full = 0, fulltime = 0;
  char *src;
  int i;
  char buf[0x100], c, *s, *t;
  struct stat64 sbuf;
  struct dirent *de;
  DIR *d;

  argv++; argc--;

  if(argc >= 1 && !strcmp(*argv, "-l")) {
    argv++; argc--;
    full = 1;
  }

  if(argc >= 1 && !strcmp(*argv, "--full-time")) {
    argv++; argc--;
    fulltime = 1;
  }

  src = argc ? *argv : ".";

  if(!(d = opendir(src))) {
    fprintf(stderr, "%s: No such file or directory\n", src);
    return 1;
  }

  while((de = readdir(d))) {
    if(full) {
      sprintf(buf, "%s/%s", src, de->d_name);
      i = lstat64(buf, &sbuf);
      if(i) {
        printf("?????????  %s\n", de->d_name);
      }
      else {
             if(S_ISREG(sbuf.st_mode))  c = '-';
        else if(S_ISDIR(sbuf.st_mode))  c = 'd';
        else if(S_ISLNK(sbuf.st_mode))  c = 'l';
        else if(S_ISCHR(sbuf.st_mode))  c = 'c';
        else if(S_ISBLK(sbuf.st_mode))  c = 'b';
        else if(S_ISFIFO(sbuf.st_mode)) c = 'p';
        else if(S_ISSOCK(sbuf.st_mode)) c = 's';
        else c = '?';

        t = NULL;
        if(c == 'l') t = read_symlink(buf);

        buf[10] = 0;
        buf[0] = c;

        buf[1] = (sbuf.st_mode & S_IRUSR) ? 'r' : '-';
        buf[4] = (sbuf.st_mode & S_IRGRP) ? 'r' : '-';
        buf[7] = (sbuf.st_mode & S_IROTH) ? 'r' : '-';
        buf[2] = (sbuf.st_mode & S_IWUSR) ? 'w' : '-';
        buf[5] = (sbuf.st_mode & S_IWGRP) ? 'w' : '-';
        buf[8] = (sbuf.st_mode & S_IWOTH) ? 'w' : '-';
        buf[3] = (sbuf.st_mode & S_IXUSR) ? 'x' : '-';
        buf[6] = (sbuf.st_mode & S_IXGRP) ? 'x' : '-';
        buf[9] = (sbuf.st_mode & S_IXOTH) ? 'x' : '-';
        if((sbuf.st_mode & S_ISUID)) {
          buf[3] = (sbuf.st_mode & S_IXUSR) ? 's' : 'S';
        }
        if((sbuf.st_mode & S_ISGID)) {
          buf[6] = (sbuf.st_mode & S_IXGRP) ? 's' : 'S';
        }
        if((sbuf.st_mode & S_ISVTX)) {
          buf[9] = (sbuf.st_mode & S_IXOTH) ? 't' : 'T';
        }

        s = ctime(&sbuf.st_mtime);
        if(fulltime) {
          s[24] = 0;
        }
        else {
          s += 4; s[12] = 0;
        }

        printf("%s %4d %-8d %-8d %8lld %s %s",
          buf,
          (int) sbuf.st_nlink,
          (int) sbuf.st_uid,
          (int) sbuf.st_gid,
          (long long) sbuf.st_size,
          s,
          de->d_name
        );
        if(t) printf(" -> %s", t);
        printf("\n");
      }
    }
    else {
      printf("%s\n", de->d_name);
    }
  }

  closedir(d);

  return 0;
}


/*
 * Redirect all output of system() to tty3.
 */
int util_sh_main(int argc, char **argv)
{
  close(3);

  return lsh_main(argc, argv);
}


char *util_process_name(pid_t pid)
{
  FILE *f;
  char proc_status[64];
  static char buf[64];

  *buf = 0;
  sprintf(proc_status, "/proc/%u/status", (unsigned) pid);
  if((f = fopen(proc_status, "r"))) {
    if(fscanf(f, "Name: %30s", buf) != 1) *buf = 0;
    fclose(f);
  }

  return buf;
}


int util_rm_main(int argc, char **argv)
{
  int i;

  argv++; argc--;

  while(argc--) {
    i = unlink(*argv);
    if(i) {
      fprintf(stderr, "rm: "); perror(*argv);
      return errno;
    }
    argv++;
  }

  return 0;
}


int util_mv_main(int argc, char **argv)
{
  int i;

  argv++; argc--;

  if(argc != 2) return -1;

  i = rename(argv[0], argv[1]);
  if(i) {
    i = errno;
    fprintf(stderr, "mv: "); perror(argv[0]);
  }

  return i;
}


int util_ln_main(int argc, char **argv)
{
  int sym = 0, i;

  argv++; argc--;

  if(argc >= 1 && !strcmp(*argv, "-s")) {
    argv++; argc--;
    sym = 1;
  }

  if(argc != 2) return -1;

  i = sym ? symlink(argv[0], argv[1]) : link(argv[0], argv[1]);
  if(i) {
    i = errno;
    fprintf(stderr, "ln: "); perror(argv[0]);
  }

  return i;
}


int util_swapon_main(int argc, char **argv)
{
  int i;

  argv++; argc--;

  if(argc != 1) return -1;

  i = swapon(*argv, 0);

  if(i) {
    i = errno;
    fprintf(stderr, "swapon: "); perror(*argv);
  }

  return i;
}


int util_swapoff_main(int argc, char **argv)
{
  int i;

  argv++; argc--;

  if(argc != 1) return -1;

  i = swapoff(*argv);

  if(i) {
    i = errno;
    fprintf(stderr, "swapoff: "); perror(*argv);
  }

  return i;
}


int util_lsmod_main(int argc, char **argv)
{
  return system("cat /proc/modules");
}


int util_raidautorun_main(int argc, char **argv)
{
  int err = 0;
  int fd;

  if((fd = open("/dev/md0", O_RDWR)) >= 0) {
    if(ioctl(fd , RAID_AUTORUN, 0)) {
      err = errno;
      perror("/dev/md0");
    }
    close(fd);
  }
  else {
    err = errno;
    perror("/dev/md0");
  }

  return err;
}


void util_free_mem()
{
  file_t *f0, *f;
  int i, mem_total = 0, mem_free = 0, mem_free_swap = 0;
  char *s;

  f0 = file_read_file("/proc/meminfo", kf_mem);

  for(f = f0; f; f = f->next) {
    switch(f->key) {
      case key_memtotal:
      case key_swaptotal:
        i = strtoul(f->value, &s, 10);
        if(!*s || *s == ' ') mem_total += i;
        break;

      case key_memfree:
      case key_buffers:
      case key_cached:
      case key_swapfree:
        i = strtol(f->value, &s, 10);
        if(!*s || *s == ' ') {
          mem_free += i;
          if(f->key == key_swapfree) {
            mem_free_swap += i;
          }
        }
        break;

      default:
        break;
    }
  }

  file_free_file(f0);

  config.memory.total = mem_total;
  config.memory.free = mem_free;
  config.memory.free_swap = mem_free_swap;

  util_update_meminfo();
}


void util_update_meminfo()
{
  int rd_mem = 0;

  // FIXME: do something with download files ???

  config.memory.current = config.memory.free - (rd_mem >> 10);
}


int util_free_main(int argc, char **argv)
{
  util_free_mem();

  printf("MemTotal: %9d kB\nMemFree: %10d kB\n", config.memory.total, config.memory.free);

  return 0;
}


int util_mkdir_main(int argc, char **argv)
{
  int i;

  argv++; argc--;

  while(argc--) {
    i = mkdir(*argv, 0755);
    if(i) {
      fprintf(stderr, "mkdir: "); perror(*argv);
      return errno;
    }
    argv++;
  }

  return 0;
}


int util_chroot_main(int argc, char **argv)
{
  int i;

  argv++; argc--;

  if(argc) {
    i = chroot(*argv);
    if(i) {
      fprintf(stderr, "chroot: "); perror(*argv);
      return errno;
    }
    argv++;
    argc--;
    chdir("/");
    i = argc ? execvp(*argv, argv) : execlp("sh", "/bin/sh", NULL);
    if(i) {
      fprintf(stderr, "chroot: "); perror(*argv);
      return errno;
    }
  }

  return 0;
}


int util_kill_main(int argc, char **argv)
{
  int i, sig = SIGTERM;
  pid_t pid;
  char *s;

  argv++; argc--;

  if(**argv == '-') {
    sig = strtol(*argv + 1, &s, 0);
    if(*s) return fprintf(stderr, "kill: bad signal spec \"%s\"\n", *argv + 1), 1;

    argv++;
    argc--;
  }

  while(argc--) {
    pid = strtoul(*argv, &s, 0);
    if(*s) return fprintf(stderr, "kill: %s: no such pid\n", *argv), 1;
    i = kill(pid, sig);
    if(i) {
      fprintf(stderr, "kill: "); perror(*argv);
      return errno;
    }
    argv++;
  }

  return 0;
}


int util_killall_main(int argc, char **argv)
{
  int sig = SIGTERM;
  char *s;

  argv++; argc--;

  if(**argv == '-') {
    sig = strtol(*argv + 1, &s, 0);
    if(*s) return fprintf(stderr, "kill: bad signal spec \"%s\"\n", *argv + 1), 1;

    argv++;
    argc--;
  }

  while(argc--) util_killall(*argv++, sig);

  return 0;
}


int util_bootpc_main(int argc, char **argv)
{
  int i;
  char *dev = "eth0";

  argv++; argc--;

  if(argc && !strcmp(*argv, "-t")) {
    bootp_testing = 1;
    argc--; argv++;
  }

  if(argc) {
    dev = *argv;
  }

  i = performBootp(dev,
    "255.255.255.255", "", config.net.bootp_timeout,
    0, NULL, 0, 1, BP_PUT_ENV | BP_PRINT_OUT, 1
  );

  return i;
}


slist_t *slist_new()
{
  return calloc(1, sizeof (slist_t));
}


slist_t *slist_free(slist_t *sl)
{
  slist_t *next;

  for(; sl; sl = next) {
    next = sl->next;
    if(sl->key) free(sl->key);
    if(sl->value) free(sl->value);
    free(sl);
  }

  return NULL;
}


slist_t *slist_free_entry(slist_t **sl0, char *str)
{
  slist_t *sl, *sl_prev, sl_tmp = { };

  if(!str) return *sl0;

  sl_tmp.next = *sl0;

  for(sl_prev = &sl_tmp, sl = sl_prev->next; sl; sl = sl->next) {
    if(sl->key && !strcmp(sl->key, str)) {
      free(sl->key);
      if(sl->value) free(sl->value);
      sl_prev->next = sl->next;
      free(sl);
      sl = sl_prev;
    }
    else {
      sl_prev = sl;
    }
  }

  return *sl0 = sl_tmp.next;
}


slist_t *slist_append(slist_t **sl0, slist_t *sl)
{
  for(; *sl0; sl0 = &(*sl0)->next);
  return *sl0 = sl;
}


slist_t *slist_append_str(slist_t **sl0, char *str)  
{
  slist_t *sl;

  sl = slist_append(sl0, slist_new());
  sl->key = strdup(str);

  return sl;
}


slist_t *slist_add(slist_t **sl0, slist_t *sl)
{
  sl->next = *sl0;
  return *sl0 = sl;
}


slist_t *slist_assign_values(slist_t **sl0, char *str)
{
  int todo = 0;
  slist_t *sl, *sl1;

  if(!sl0) return NULL;

  if(!str) str = "";

  switch(*str) {
    case '+':
      todo = 1;
      str++;
      break;

    case '-':
      todo = -1;
      str++;
      break;
  }

  sl1 = slist_split(',', str);

  if(todo) {
    for(sl = sl1; sl; sl = sl->next) {
      if(todo > 0) {
        if(!slist_getentry(*sl0, sl->key)) slist_append_str(sl0, sl->key);
      }
      else {
        slist_free_entry(sl0, sl->key);
      }
    }
  }
  else {
    slist_free(*sl0);
    *sl0 = sl1;
    sl1 = NULL;
  }

  slist_free(sl1);

  return *sl0;
}


slist_t *slist_getentry(slist_t *sl, char *key)
{
  if(key) {
    for(; sl; sl = sl->next) {
      if(sl->key && !strcmp(key, sl->key)) return sl;
    }
  }

  return NULL;
}


slist_t *slist_reverse(slist_t *sl0)
{
  slist_t *sl1 = NULL, *sl, *next;

  for(sl = sl0; sl; sl = next) {
    next = sl->next;
    slist_add(&sl1, sl);
  }

  return sl1;
}


slist_t *slist_sort(slist_t *sl0, int (*cmp_func)(const void *, const void *))
{
  int i, list_len;
  slist_t *sl1 = NULL, *sl;
  slist_t **slist_array;

  for(list_len = 0, sl = sl0; sl; sl = sl->next) list_len++;
  if(list_len < 2) return sl0;

  slist_array = malloc(list_len * sizeof *slist_array);

  for(i = 0, sl = sl0; sl; sl = sl->next) slist_array[i++] = sl;

  qsort(slist_array, list_len, sizeof *slist_array, cmp_func);

  for(i = 0; i < list_len; i++) {
    slist_append(&sl1, slist_array[i])->next = NULL;
  }

  free(slist_array);

  return sl1;
}


/*
 * split a string
 *
 * Note: works differently depending on whether 'del' is whitespace or not!
 */
slist_t *slist_split(char del, char *text)
{
  slist_t *sl0 = NULL, *sl;
  int i, len;
  char *s, *t;

  if(!text) return NULL;

  text = strdup(text);

  if(isspace(del)) {
    len = strlen(text);

    for(i = 0; i < len; i++) if(isspace(text[i])) text[i] = 0;

    for(s = text; s < text + len; s++) {
      if(*s && (s == text || !s[-1])) {
        sl = slist_append(&sl0, slist_new());
        sl->key = strdup(s);
      }
    }
  }
  else {
    for(s = text; (t = strchr(s, del)); s = t + 1) {
      *t = 0;
      sl = slist_append(&sl0, slist_new());
      sl->key = strdup(s);
    }
    sl = slist_append(&sl0, slist_new());
    sl->key = strdup(s);
  }

  free(text);

  return sl0;
}


char *slist_join(char *del, slist_t *str)
{
  char *s;
  slist_t *str0;
  int len = 0, del_len = 0;

  if(del) del_len = strlen(del);

  for(str0 = str; str0; str0 = str0->next) {
    if(str0->key) len += strlen(str0->key);
    if(str0->next) len += del_len;
  }

  if(!len) return NULL;

  len++;

  s = calloc(len, 1);

  for(; str; str = str->next) {
    if(str->key) strcat(s, str->key);
    if(str->next && del) strcat(s, del);
  }

  return s;
}


/*
 * Clear 'inet' und add 'name' to it.
 *
 * 'inet' is unchanged if 'name' is NULL.
 * If 'name' is "", 'inet' is just cleared.
 */
void name2inet(inet_t *inet, char *name)
{
  inet_t inet_new = {};

  if(!inet || !name) return;

  if(*name) inet_new.name = strdup(name);

  if(inet->name) free(inet->name);

  *inet = inet_new;
}


void s_addr2inet(inet_t *inet, unsigned long s_addr)
{
  inet_t inet_new = {};

  if(!inet) return;

  if(inet->name) free(inet->name);

  inet_new.ip.s_addr = s_addr;
  inet_new.name = strdup(inet_ntoa(inet_new.ip));

  if(inet_new.name) {
    inet_new.ok = 1;
    inet_new.ipv4 = 1;
  }

  *inet = inet_new;
}


char *inet2print(inet_t *inet)
{
  static char buf[256];
  const char *ip = NULL, *ip6 = NULL;
  char ip_buf[INET_ADDRSTRLEN], ip6_buf[INET6_ADDRSTRLEN];
  char prefix4[64], prefix6[64];

  if(!inet || (!inet->name && !inet->ok)) return "(no ip)";

  sprintf(buf, "%s", inet->name ?: "[no name]");

  *prefix4 = *prefix6 = 0;
  if(inet->prefix4) sprintf(prefix4, "/%u", inet->prefix4);
  if(inet->prefix6) sprintf(prefix6, "/%u", inet->prefix6);

  if(!inet->ipv4 && !inet->ipv6) {
    sprintf(buf + strlen(buf), " (no ip)");
    return buf;
  }

  if(inet->ipv4) ip = inet_ntop(AF_INET, &inet->ip, ip_buf, sizeof ip_buf);
  if(inet->ipv6) ip6 = inet_ntop(AF_INET6, &inet->ip6, ip6_buf, sizeof ip6_buf);

  if(ip && ip6) {
    sprintf(buf + strlen(buf), " (ip: %s%s, ip6: %s%s)", ip, prefix4, ip6, prefix6);
  }
  else if(ip) {
    if(!inet->name || strcmp(inet->name, ip) || *prefix4) {
      sprintf(buf + strlen(buf), " (ip: %s%s)", ip, prefix4);
    }
  }
  else if(ip6) {
    if(!inet->name || strcmp(inet->name, ip6) || *prefix6) {
      sprintf(buf + strlen(buf), " (ip6: %s%s)", ip6, prefix6);
    }
  }

  return buf;
}


/*
 * copy strings, *dst points to malloc'ed memory
 */
void str_copy(char **dst, char *src)
{
  char *s;

  if(!dst) return;

  s = src ? strdup(src) : NULL;
  if(*dst) free(*dst);
  *dst = s;
}


void strprintf(char **buf, char *format, ...)
{
  char sbuf[1024];
  
  va_list args;

  va_start(args, format);
  vsnprintf(sbuf, sizeof sbuf - 1, format, args);
  va_end(args);

  sbuf[sizeof sbuf - 1] = 0;

  if(*buf) free(*buf);

  *buf = strcpy(malloc(strlen(sbuf) + 1), sbuf);
}


char *get_instmode_name(instmode_t instmode)
{
  return file_num2sym("no scheme", instmode);
}


char *get_instmode_name_up(instmode_t instmode)
{
  static char *name = NULL;
  int i;

  str_copy(&name, file_num2sym("no scheme", instmode));

  if(name) {
    for(i = 0; name[i]; i++) name[i] = toupper(name[i]);
  }

  return name;
}


int util_wget_main(int argc, char **argv)
{
  url_t *url;
  unsigned flags = URL_FLAG_PROGRESS + URL_FLAG_NOUNLINK;
  char *label = NULL;
  int err;

  config.test = 1;

  config.download.base = strdup("/tmp/download");
  mkdir(config.download.base, 0755);
  config.mountpoint.base = strdup("/tmp/mounts/");
  mkdir("/tmp/mounts", 0755);

  str_copy(&config.net.cifs.binary, "/sbin/mount.cifs");

  argv++; argc--;

  while(
    (argc && !strcmp(*argv, "-v") && (config.debug++, argc--, argv++)) ||
    (argc && !strcmp(*argv, "-z") && (flags += URL_FLAG_UNZIP, argc--, argv++)) ||
    (argc && !strcmp(*argv, "-l") && (label = argv[1], argc -= 2, argv += 2))
  );

  if(argc != 2) return fprintf(stderr, "usage: wget url file\n"), 1;

  url = url_set(argv[0]);

  err = url_read_file(url, NULL, NULL, argv[1], label, flags);

  url_umount(url);
  url_free(url);

  url_cleanup();

  return 0;
}


int util_fstype_main(int argc, char **argv)
{
  char *s;

  argv++; argc--;

  if(!argc) return fprintf(stderr, "usage: fstype blockdevice\n"), 1;

  while(argc--) {
    s = fstype(*argv);
    printf("%s: %s\n", *argv, s ?: "unknown fs");
    argv++;
  }

  return 0;
}


/*
 * Return fs name. If we have to load a module first, return it in *module.
 */
char *util_fstype(char *dev, char **module)
{
  char *type, *s;
  file_t *f0, *f;

  type = dev ? fstype(dev) : NULL;

  if(module) *module = type;

  if(!type) return NULL;

  if(module) {
    /* iso9660 is special */
    if(*module && !strcmp(*module, "iso9660")) *module = "isofs";

    if(
      !strcmp(type, "cpio") ||
      !strcmp(type, "rpm") ||
      (config.ntfs_3g && !strcmp(type, "ntfs"))
    ) {
      *module = NULL;
    }
    else {
      f0 = file_read_file("/proc/filesystems", kf_none);
      for(f = f0; f; f = f->next) {
        s = strcmp(f->key_str, "nodev") ? f->key_str : f->value;
        if(!strcmp(s, type)) {
          *module = NULL;
          break;
        }
      }
      file_free_file(f0);
    }
  }

  return type;
}


void util_extend_usr1(int signum)
{
  extend_ready = 1;
}


int util_extend(char *extension, char task, int verbose)
{
  FILE *f, *w;
  int err = 0;
  char buf[1024];

  extend_ready = 0;
  signal(SIGUSR1, util_extend_usr1);

  unlink("/tmp/extend.result");
  f = fopen("/tmp/extend.job", "w");
  if(f) {
    fprintf(f, "%d %c %s\n", (int) getpid(), task, extension);
    fclose(f);

    if(util_check_exist("/usr/src/packages") || getuid()) config.test = 1;

    if(config.test) {
      util_killall("linuxrc", SIGUSR1);
    }
    else {
      if(kill(1, SIGUSR1)) err = 2;
    }

    if(!err) {
      while(!extend_ready) { sleep(1); }

      if((f = fopen("/tmp/extend.result", "r"))) {
        fscanf(f, "%d", &err);
        fclose(f);
      }
    }
  }
  else {
    err = 1;
  }

  f = fopen("/tmp/extend.log", "r");
  if(f) {
    w = fopen("/var/log/extend", "a");
    while(fgets(buf, sizeof buf, f)) {
      if(verbose > 0) printf("%s", buf);
      if(w) fprintf(w, "%s", buf);
    }
    if(w) fclose(w);
    fclose(f);
  }

  if(verbose >= 0) printf("%s: extend %s\n", extension, err ? "failed" : "ok");

  return err;
}


int util_extend_main(int argc, char **argv)
{
  int err = 0;
  char task = 'a';
  struct { unsigned verbose:1; unsigned help:1; } opt = {};

  argv++; argc--;

  while(argc) {
    if(!strcmp(*argv, "-r")) {
      task = 'r';
    }
    else if(!strcmp(*argv, "-h") || !strcmp(*argv, "--help")) {
      opt.help = 1;
    }
    else if(!strcmp(*argv, "-v")) {
      opt.verbose = 1;
    }
    else {
      break;
    }
    argv++; argc--;
  }

  if(!argc || opt.help) {
    return fprintf(stderr, "Usage: extend [-v] [-r] extension\nAdd or remove inst-sys extension.\n"), 1;
  }

  err = util_extend(*argv, task, opt.verbose);

  // remove it to keep internal list correct
  if(err && task == 'a') util_extend(*argv, 'r', -1);

  return err;
}


/*
 * returns loop device used
 */
char *util_attach_loop(char *file, int ro)
{
  struct loop_info loopinfo;
  int fd, rc, i, device, ok = 0;
  static char buf[32];

  if((fd = open(file, (ro ? O_RDONLY : O_RDWR) | O_LARGEFILE)) < 0) {
    perror(file);
    return NULL;
  }

  for(i = 0; i < 64; i++) {
    sprintf(buf, "/dev/loop%d", i);
    if((device = open(buf, (ro ? O_RDONLY : O_RDWR) | O_LARGEFILE)) >= 0) {
      memset(&loopinfo, 0, sizeof loopinfo);
      strcpy(loopinfo.lo_name, file);
      rc = ioctl(device, LOOP_SET_FD, fd);
      if(rc != -1) rc = ioctl(device, LOOP_SET_STATUS, &loopinfo);
      close(device);
      if(rc != -1) {
        ok = 1;
        break;
      }
    }
  }

  close(fd);

  return ok ? buf : NULL;
}


int util_detach_loop(char *dev)
{
  int i, fd;

  if((fd = open(dev, O_RDONLY | O_LARGEFILE)) < 0) {
    if(config.debug) perror(dev);
    return -1;
  }

  if((i = ioctl(fd, LOOP_CLR_FD, 0)) == -1) {
    if(config.debug) perror(dev);
  }

  close(fd);

  return i;
}


int util_mount(char *dev, char *dir, unsigned long flags, slist_t *file_list)
{
  char *type, *loop_dev, *cmd = NULL, *module, *tmp_dev, *cpio_opts = NULL, *s, *buf = NULL;
  int err = -1;
  struct stat64 sbuf;

  if(!dev || !dir) return -1;

  if(
    config.mountpoint.base &&
    strstr(dir, config.mountpoint.base) == dir &&
    stat64(dir, &sbuf)
  ) {
    mkdir(dir, 0755);
  }

  if(stat64(dev, &sbuf)) {
    fprintf(stderr, "mount: %s: %s\n", dev, strerror(errno));
    return -1;
  }

  if(S_ISDIR(sbuf.st_mode)) {
    err = mount(dev, dir, "none", MS_BIND, 0);
    if(err && config.run_as_linuxrc) {
      fprintf(stderr, "mount: %s: %s\n", dev, strerror(errno));
    }
    return err;
  }

  if(!S_ISREG(sbuf.st_mode) && !S_ISBLK(sbuf.st_mode)) {
    fprintf(stderr, "mount: %s: not a block device\n", dev);
    return -1;
  }

  type = util_fstype(dev, &module);
  if(module) mod_modprobe(module, NULL);

  if(
    type &&
    (!strcmp(type, "cpio") || !strcmp(type, "rpm"))
  ) {
    char *buf = NULL;
    char *msg;

    err = mount("tmpfs", dir, "tmpfs", 0, "size=0,nr_inodes=0");
    if(err) {
      if(config.run_as_linuxrc) fprintf(stderr, "mount: tmpfs: %s\n", strerror(errno));
      return err;
    }

    chmod(dir, 0755);

    str_copy(&cpio_opts, "--quiet --sparse -dimu --no-absolute-filenames");

    if(file_list) {
      s = slist_join("' '", file_list);
      strprintf(&cpio_opts, "%s '%s'", cpio_opts, s);
      free(s);
    }

    if(!strcmp(type, "cpio")) {
      strprintf(&buf, "cd %s ; cpio %s < %s", dir, cpio_opts, dev);
      msg = "cpio";
    }
    else {
      strprintf(&buf, "cd %s ; rpm2cpio %s | cpio %s", dir, dev, cpio_opts);
      msg = "rpm unpacking";
    }

    str_copy(&cpio_opts, NULL);

    if(config.debug) fprintf(stderr, "%s\n", buf);
    err = system(buf);
    free(buf);
    buf = NULL;

    if(err) {
      if(config.run_as_linuxrc) fprintf(stderr, "mount: %s failed\n", msg);
      umount(dir);
      return err;
    }
    else if(config.squash) {
      tmp_dev = new_download();
      // if we downloaded the file, overwrite it; else make a new copy
      if(strncmp(dev, config.download.base, strlen(config.download.base))) {
        tmp_dev = new_download();
      }
      else {
        tmp_dev = dev;
      }
      fprintf(stderr, "%s -> %s: converting to squashfs\n", dev, tmp_dev);
      strprintf(&buf, "mksquashfs %s %s -noappend -no-progress >%s", dir, tmp_dev, config.debug ? "&2" : "/dev/null");
      err = system(buf);
      if(err && config.run_as_linuxrc) fprintf(stderr, "mount: mksquashfs failed\n");
      if(!err) {
        umount(dir);
        err = util_mount(tmp_dev, dir, flags, NULL);
      }
    }

    return err;
  }

  if(type &&
    (
      S_ISREG(sbuf.st_mode) ||
      (!strcmp(type, "cramfs") && strstr(dev, "/dev/ram") == dev)
    )
  ) {
    if(config.run_as_linuxrc) fprintf(stderr, "mount: %s: we need a loop device\n", dev);
    loop_dev = util_attach_loop(dev, (flags & MS_RDONLY) ? 1 : 0);
    if(!loop_dev) {
      fprintf(stderr, "mount: no usable loop device found\n");
      return -1;
    }
    if(config.run_as_linuxrc) fprintf(stderr, "mount: using %s\n", loop_dev);

    strprintf(&buf, "%s/file_", config.download.base);

    // remove downloaded files immediately (so we don't have to cleanup after umount)
    if(!strncmp(dev, buf, strlen(buf))) unlink(dev);

    str_copy(&buf, NULL);

    dev = loop_dev;
  }

  if(config.ntfs_3g && type && !strcmp(type, "ntfs")) {
    asprintf(&cmd, "/bin/mount -t ntfs-3g%s %s %s", (flags & MS_RDONLY) ? " -oro" : "", dev, dir);
    err = system(cmd);
    free(cmd);
  }
  else if(type) {
    err = mount(dev, dir, type, flags, 0);
    if(err && config.run_as_linuxrc) {
      fprintf(stderr, "mount: %s: %s\n", dev, strerror(errno));
    }
  }
  else {
    fprintf(stderr, "%s: unknown fs type\n", dev);
    err = -1;
  }

  return err;
}


int util_mount_ro(char *dev, char *dir, slist_t *file_list)
{
  return util_mount(dev, dir, MS_MGC_VAL | MS_RDONLY, file_list);
}


int util_mount_rw(char *dev, char *dir, slist_t *file_list)
{
  return util_mount(dev, dir, 0, file_list);
}


void util_update_netdevice_list(char *module, int add)
{
  file_t *f0, *f1, *f;
  slist_t *sl;

  f0 = file_read_file("/proc/net/dev", kf_none);
  if(!f0) return;

  /* skip 2 lines */
  if((f1 = f0->next)) f1 = f1->next;

  if(add) {
    for(f = f1; f; f = f->next) {
      if(!strcmp(f->key_str, "lo")) continue;
      if(strstr(f->key_str, "sit") == f->key_str) continue;
      if(!slist_getentry(config.net.devices, f->key_str)) {
        sl = slist_append_str(&config.net.devices, f->key_str);
        str_copy(&sl->value, module);
      }
    }
  }
  else {
    for(sl = config.net.devices; sl; sl = sl->next) {
      if(!file_getentry(f1, sl->key)) {
        str_copy(&sl->key, NULL);
        str_copy(&sl->value, NULL);
      }
    }
  }

  file_free_file(f0);
}


int util_update_disk_list(char *module, int add)
{
  str_list_t *hsl;
  slist_t *sl;
  int added = 0;

  hd_data_t *hd_data = calloc(1, sizeof *hd_data);

  hd_data->flags.list_md = 1;
  fix_device_names(hd_list(hd_data, hw_disk, 1, NULL));

  if(add) {
    for(hsl = hd_data->disks; hsl; hsl = hsl->next) {
      if(!slist_getentry(config.disks, hsl->str)) {
        sl = slist_append_str(&config.disks, hsl->str);
        str_copy(&sl->value, module);
        added++;
      }
    }
    for(hsl = hd_data->partitions; hsl; hsl = hsl->next) {
      if(!slist_getentry(config.partitions, hsl->str)) {
        sl = slist_append_str(&config.partitions, hsl->str);
        str_copy(&sl->value, module);
        added++;
      }
    }
  }
  else {
    for(sl = config.disks; sl; sl = sl->next) {
      if(!search_str_list(hd_data->disks, sl->key)) {
        str_copy(&sl->key, NULL);
        str_copy(&sl->value, NULL);
      }
    }
    for(sl = config.partitions; sl; sl = sl->next) {
      if(!search_str_list(hd_data->partitions, sl->key)) {
        str_copy(&sl->key, NULL);
        str_copy(&sl->value, NULL);
      }
    }
  }

  hd_free_hd_data(hd_data);
  free(hd_data);

  return added;
}


void util_update_cdrom_list()
{
  slist_t *sl;
  file_t *f0, *f;
  char *s, *t;

  config.cdroms = slist_free(config.cdroms);

  f0 = file_read_file("/proc/sys/dev/cdrom/info", kf_none);

  for(f = f0; f; f = f->next) {
    if(!strcmp(f->key_str, "drive") && strstr(f->value, "name:") == f->value) {
      s = strchr(f->value, ':') + 1;
      while((t = strsep(&s, " \t\n"))) {
        if(!*t) continue;
        sl = slist_add(&config.cdroms, slist_new());
        str_copy(&sl->key, t);
      }
      break;
    }
  }

  file_free_file(f0);
}


void util_update_swap_list()
{
  file_t *f0, *f;

  config.swaps = slist_free(config.swaps);

  f0 = file_read_file("/proc/swaps", kf_none);

  for(f = f0; f; f = f->next) {
    if(f->key == key_none && strstr(f->key_str, "/dev/") == f->key_str) {
      slist_append_str(&config.swaps, f->key_str + sizeof "/dev/" - 1);
    }
  }

  file_free_file(f0);
}


int util_is_mountable(char *file)
{
  int i, compressed = 0;

  if(util_check_exist(file) == 'd') return 1;

  i = util_fileinfo(file, NULL, &compressed);

  return i || compressed ? 0 : 1;
}


void util_set_serial_console(char *str)
{
  slist_t *sl;

  if(!str || !*str) return;

  /* not a serial console */
  if(
    !strncmp(str, "tty", 3) &&
    (str[3] == 0 || (str[3] >= '0' && str[3] <= '9'))
  ) return;

  str_copy(&config.serial, str);

  sl = slist_split(',', config.serial);

  if(sl) {
    /* if it's uart, don't bother to find the matching ttySx */
    str_copy(&config.console, long_dev(strcmp(sl->key, "uart") ? sl->key : "console"));
#if 0
    s = long_dev(sl->key);
    if(!config.console || strcmp(s, config.console)) {
      str_copy(&config.console, s);
      freopen(config.console, "r", stdin);
      freopen(config.console, "a", stdout);
    }
#endif
    config.textmode = 1;
  }
     
  slist_free(sl);
}


void util_set_stderr(char *name)
{
  if(!name || !*name) return;

  str_copy(&config.stderr_name, name);

  freopen(config.stderr_name, "a", stderr);

  setlinebuf(stderr);
}


void util_set_product_dir(char *prod)
{
  struct utsname ubuf;
  char *arch = "";

  if(prod && *prod) str_copy(&config.product_dir, prod);

  if(!uname(&ubuf)) {
    arch = ubuf.machine;
    if(arch[0] == 'i' && arch[2] == '8' && arch[3] == '6' && !arch[4]) arch = "i386";
  }

#if defined(__powerpc__) && !defined(__powerpc64__)
  if(!strcmp(arch, "ppc64")) arch = "ppc";
#endif

  strprintf(&config.rootimage, "boot/%s/root", arch);
  strprintf(&config.rescueimage, "boot/%s/rescue", arch);

  if(!strcmp(arch, "i386") || !strcmp(arch, "x86_64")) {
    strprintf(&config.kexec_kernel, "boot/%s/loader/linux", arch);
    strprintf(&config.kexec_initrd, "boot/%s/loader/initrd", arch);
  }
}


/*
 * Rename SCSI devices so that usb and firewire devices are last.
 */
void scsi_rename()
{
  if(!config.scsi_rename) return;

  get_scsi_list();
  rename_scsi_devs();

  scsi_rename_devices();

  free_scsi_list();
}


void scsi_rename_devices()
{
  size_t i;
  slist_t *sl;
  char **rs[] = { &config.update.dev, &config.cdrom };

  for(i = 0; i < sizeof rs / sizeof *rs; i++) {
    scsi_rename_onedevice(rs[i]);
  }

  for(sl = config.disks; sl; sl = sl->next) {
    scsi_rename_onedevice(&sl->key);
  }
}


void scsi_rename_onedevice(char **dev)
{
  unsigned u, is_long = 0;
  char *s_dev;

  if(!dev || !*dev) return;

  s_dev = *dev;

  if(!strncmp(s_dev, "/dev/", sizeof "/dev/" - 1)) {
    s_dev += sizeof "/dev/" - 1;
    is_long = 1;
  }

  for(u = 0; u < scsi_list_len; u++) {
    if(scsi_list[u]->new_name && !strcmp(scsi_list[u]->name, s_dev)) {
      str_copy(dev, is_long ? long_dev(scsi_list[u]->new_name) : scsi_list[u]->new_name);
    }
  }
}


char *short_dev(char *dev)
{
  if(dev && !strncmp(dev, "/dev/", sizeof "/dev/" - 1)) {
    dev += sizeof "/dev/" - 1;
  }
  return dev;
}

char *long_dev(char *dev)
{
  static char *buf = NULL;

  if(dev && *dev != '/') {
    strprintf(&buf, "/dev/%s", dev);
    dev = buf;
  }

  return dev;
}

/* create device files */
void util_mkdevs()
{
  FILE *f;
  size_t len;
  unsigned char *buf;
  int inodes = 0;

  fprintf(stderr, "Creating /dev tree ");

  if((f = fopen("/devz", "r"))) {
    len = (fgetc(f) & 0xff) << 8;
    len += fgetc(f) & 0xff;
    if(len) {
      buf = malloc(len);
      if(fread(buf, len, 1, f) == 1) {
        inodes = mkdevs(buf, 1);
        unlink("/devz");
      }
      free(buf);
    }
    fclose(f);
  }

  fprintf(stderr, "(%d inodes)\n", inodes);
}


/*
 * Get unique id & hw address for network device.
 *
 */
void get_net_unique_id()
{
  hd_data_t *hd_data;
  hd_t *hd, *hd_card;
  hd_res_t *res;

  if(!config.net.device) return;

  hd_data = calloc(1, sizeof *hd_data);

  add_str_list(&hd_data->only, config.net.device);

  hd = hd_list(hd_data, hw_network, 1, NULL);

  if(hd) {
    for(res = hd->res; res; res = res->next) {
      if(res->any.type == res_hwaddr) {
        str_copy(&config.net.hwaddr, res->hwaddr.addr);
        break;
      }
    }
    if((hd_card = hd_get_device_by_idx(hd_data, hd->attached_to))) {
      str_copy(&config.net.unique_id, hd_card->unique_id);
      str_copy(&config.net.cardname, hd_card->model);
    }
  }

  hd_free_hd_data(hd_data);
}


static int is_there(char *name);
static int is_dir(char *name);
static int is_link(char *name);
static char *read_symlink(char *name);
static int make_links(char *src, char *dst);


int util_lndir_main(int argc, char **argv)
{
  argv++; argc--;

  if(argc != 2) return 1;

  return make_links(argv[0], argv[1]);
}


int is_there(char *name)
{
  struct stat sbuf;

  if(stat(name, &sbuf) == -1) return 0;

  return 1;
}


int is_dir(char *name)
{
  struct stat sbuf;

  if(stat(name, &sbuf) == -1) return 0;

  if(S_ISDIR(sbuf.st_mode)) return 1;

  return 0;
}


int is_link(char *name)
{
  struct stat sbuf;

  if(lstat(name, &sbuf) == -1) return 0;

  if(S_ISLNK(sbuf.st_mode)) return 1;

  return 0;
}


/*
 * Link directory tree src to dst. Keep existing files in dst.
 */
int make_links(char *src, char *dst)
{
  DIR *dir;
  struct dirent *de;
  struct stat sbuf;
  struct utimbuf ubuf;
  char src2[0x400], dst2[0x400], tmp_dir[0x400], tmp_link[0x400], *tmp_s = NULL;
  char *s, *t;
  int err = 0;

  // fprintf(stderr, "make_links: %s -> %s\n", src, dst);

  if((dir = opendir(src))) {
    while((de = readdir(dir))) {
      if(!strcmp(de->d_name, ".") || !strcmp(de->d_name, "..")) continue;
      sprintf(src2, "%s/%s", src, de->d_name);
      sprintf(dst2, "%s/%s", dst, de->d_name);

      // fprintf(stderr, "?: %s -> %s\n", src2, dst2);

#if 0

> lndir /tmp/test/f2/{a,c}  // a + b -> c

  drwxr-xr-x   f2
  drwxr-xr-x   f2/a
  drwxr-xr-x   f2/a/dir1
  drwxr-xr-x   f2/a/dir1/dir2
  -rw-r--r--   f2/a/dir1/dir2/file1
  drwxr-xr-x   f2/b
  drwxr-xr-x   f2/b/dir1
  lrwxrwxrwx   f2/b/dir1/dir2 -> /tmp/test/f2/a/dir1/dir2
  drwxr-xr-x   f2/c
  drwxr-xr-x   f2/c/dir1
  drwxr-xr-x   f2/c/dir1/dir2
  lrwxrwxrwx   f2/c/dir1/dir2/file1 -> /tmp/test/f2/a/dir1/dir2/file1


> lndir /tmp/test/f1/{a,b}  // a + b -> b

  drwxr-xr-x   f1
  drwxr-xr-x   f1/a
  drwxr-xr-x   f1/a/dir1
  lrwxrwxrwx   f1/a/link1 -> dir1
  drwxr-xr-x   f1/b
  drwxr-xr-x   f1/b/dir1
  lrwxrwxrwx   f1/b/link1 -> dir1

#endif

      /* Why on earth '&& !is_link(src2)'??? */
      /* new try: && !relative_link() */
      if(is_dir(src2) /* && !is_link(src2) */) {
        /* add directory */

        // fprintf(stderr, "dir: %s -> %s\n", src2, dst2);

        if(is_dir(dst2)) {
          if(is_link(dst2)) {
            /* remove link and make directory */
            sprintf(tmp_dir, "%s/mklXXXXXX", dst);
            s = mkdtemp(tmp_dir);
            if(!s) {
              perror(tmp_dir);
              err = 2;
              continue;
            }
            str_copy(&tmp_s, read_symlink(dst2));
            s = tmp_s;
            if(!*s) {
              err = 3;
              continue;
            }
            if(*s != '/') {
              strcpy(tmp_link, dst2);
              t = strrchr(tmp_link, '/');
              strcpy(t ? t + 1 : tmp_link, s);
              // sprintf(tmp_link, "%s/%s", dst2, s);
              s = tmp_link;
            }
            if((err = make_links(s, tmp_dir))) continue;
            if(unlink(dst2)) {
              perror(dst2);
              err = 4;
              continue;
            }
            if(rename(tmp_dir, dst2)) {
              perror(tmp_dir);
              err = 5;
              continue;
            }
            if(stat(src2, &sbuf) != -1) {
              chmod(dst2, sbuf.st_mode);
              ubuf.actime = sbuf.st_atime;
              ubuf.modtime = sbuf.st_mtime;
              utime(dst2, &ubuf);
              lchown(dst2, sbuf.st_uid, sbuf.st_gid);
            }
          }
          if((err = make_links(src2, dst2))) continue;
        }
        else if(!is_there(dst2)) {
          unlink(dst2);
          s = src2;
          if(is_link(src2)) s = read_symlink(src2);
          if(symlink(s, dst2)) {
            perror(s);
            err = 7;
            continue;
          }
        }
      }
      else if(!is_there(dst2) || is_link(dst2)) {
        unlink(dst2);
        s = src2;
        if(is_link(src2)) s = read_symlink(src2);
        if(symlink(s, dst2)) {
          perror(s);
          err = 6;
          continue;
        }
      }
    }

    closedir(dir);

    free(tmp_s);
  }
  else {
    perror(src);
    return 1;
  }

  return err;
}


void util_notty()
{
  int fd;

  fd = open("/dev/tty", O_RDWR);

  if(fd != -1) {
    ioctl(fd, TIOCNOTTY);
    close(fd);
  }
}


void util_killall(char *name, int sig)
{
  pid_t mypid, pid;
  struct dirent *de;
  DIR *d;
  char *s;
  slist_t *sl0 = NULL, *sl;

  if(!name) return;

  mypid = getpid();

  if(!(d = opendir("/proc"))) return;

  /* make a (reversed) list of all process ids */
  while((de = readdir(d))) {
    pid = strtoul(de->d_name, &s, 10);
    if(!*s && *util_process_cmdline(pid)) {
      sl = slist_add(&sl0, slist_new());
      sl->key = strdup(de->d_name);
      sl->value = strdup(util_process_name(pid));
    }
  }

  closedir(d);

  for(sl = sl0; sl; sl = sl->next) {
    pid = strtoul(sl->key, NULL, 10);
    if(pid == mypid) continue;
    if(!strcmp(sl->value, name)) {
      if(config.debug) fprintf(stderr, "kill -%d %d\n", sig, pid);
      kill(pid, sig);
      usleep(20000);
    }
  }


  slist_free(sl0);

  while(waitpid(-1, NULL, WNOHANG) > 0);
}


void util_get_ram_size()
{
  hd_data_t *hd_data;
  hd_t *hd;
  hd_res_t *res;

  if(config.memory.ram) return;

  hd_data = calloc(1, sizeof *hd_data);

  hd = hd_list(hd_data, hw_memory, 1, NULL);

  if(hd && hd->base_class.id == bc_internal && hd->sub_class.id == sc_int_main_mem) {
    for(res = hd->res; res; res = res->next) {
      if(res->any.type == res_phys_mem) {
        config.memory.ram = res->phys_mem.range >> 20;
        fprintf(stderr, "RAM size: %u MB\n", config.memory.ram);
        break;
      }
    }
  }

  hd_free_hd_data(hd_data);
}


/*
 * Load basic usb support.
 */
void util_load_usb()
{
  hd_data_t *hd_data;
  hd_t *hd, *hd_usb;
  static int loaded = 0;

  if(loaded) return;

  loaded = 1;

  hd_data = calloc(1, sizeof *hd_data);

  hd_usb = hd_list(hd_data, hw_usb_ctrl, 1, NULL);

  /* ehci needs to be loaded first */
  for(hd = hd_usb; hd; hd = hd->next) {
    if(
      hd->base_class.id == bc_serial &&
      hd->sub_class.id == sc_ser_usb &&
      hd->prog_if.id == pif_usb_ehci
    ) {
      mod_modprobe("ehci-hcd", NULL);
      break;
    }
  }

  for(hd = hd_usb; hd; hd = hd->next) activate_driver(hd_data, hd, NULL, 0);

  hd_free_hd_data(hd_data);
}

int util_set_sysfs_attr(char* attr, char* value)
{
  int i, fd;

  if((fd = open(attr, O_WRONLY)) < 0) return -1;

  i = write(fd, value, strlen(value));
  
  close(fd);

  return i < 0 ? i : 0;
}

int util_get_sysfs_int_attr(char* attr, int *retval)
{
  int i, fd;
  char buf[1024];

  if((fd = open(attr, O_RDONLY)) < 0) return -1;

  i = read(fd, buf, sizeof buf - 1);

  close(fd);

  if(i >= 0) {
    buf[i] = 0;
  }
  else {
    return -1;
  }
    
  *retval = strtol(buf, NULL, 0);

  return 0;
}

char *print_driverid(driver_t *drv, int with_0x)
{
  static char buf[256], *s;
  int items;

  *buf = 0;

  if(!drv) return buf;

  items = 7;
  if(!drv->driver_data) {
    items = 6;
    if(!drv->class_mask) {
      items = 4;
      if(drv->subdevice == ~0) {
        items--;
        if(drv->subvendor == ~0) {
          items--;
          if(drv->device == ~0) {
            items--;
            if(drv->vendor == ~0) {
              items--;
            }
          }
        }
      }
    }
  }

  if(!items) return buf;

  s = with_0x ? "0x" : "";

  sprintf(buf, "%s%x", s, drv->vendor);
  if(items >= 2) sprintf(buf + strlen(buf), " %s%x", s, drv->device);
  if(items >= 3) sprintf(buf + strlen(buf), " %s%x", s, drv->subvendor);
  if(items >= 4) sprintf(buf + strlen(buf), " %s%x", s, drv->subdevice);
  if(items >= 5) sprintf(buf + strlen(buf), " %s%x %s%x", s, drv->class, s, drv->class_mask);
  if(items >= 7) sprintf(buf + strlen(buf), " %s%lx", s, drv->driver_data);

  return buf;
}


int apply_driverid(driver_t *drv)
{
  char buf[256], *name;
  FILE *f;

  if(!drv) return 0;

  if(!(name = drv->sysfs_name ?: drv->name)) return 0;

  sprintf(buf, "/sys/bus/pci/drivers/%s/new_id", name);

  if(util_check_exist(buf) != 'r') return 0;

  if(!(f = fopen(buf, "w"))) return 0;
  fprintf(f, "%s\n", print_driverid(drv, 0));
  fclose(f);

  fprintf(stderr, "new id [%s]: %s\n", name, print_driverid(drv, 0));

  return 1;
}


void store_driverid(driver_t *drv)
{
  char first = ' ';
  FILE *f;

  if(!drv) return;

  if(drv->name && (f = fopen("/var/lib/hardware/hd.ids", "a"))) {
    fprintf(f, "\n# %s\n", print_driverid(drv, 1));

    if(((drv->class_mask >> 16) & 0xff) == 0xff) {
      fprintf(f, "%cbaseclass.id\t\t0x%03x\n", first, (drv->class >> 16) & 0xff);
      first = '&';
    }

    if(((drv->class_mask >> 8) & 0xff) == 0xff) {
      fprintf(f, "%csubclass.id\t\t0x%02x\n", first, (drv->class >> 8) & 0xff);
      first = '&';
    }

    if((drv->class_mask & 0xff) == 0xff) {
      fprintf(f, "%cprogif.id\t\t0x%02x\n", first, drv->class & 0xff);
      first = '&';
    }

    if(drv->vendor != ~0) {
      fprintf(f, "%cvendor.id\t\tpci 0x%04x\n", first, drv->vendor & 0xffff);
      first = '&';
    }

    if(drv->device != ~0) {
      fprintf(f, "%cdevice.id\t\tpci 0x%04x\n", first, drv->device & 0xffff);
      first = '&';
    }

    if(drv->subvendor != ~0) {
      fprintf(f, "%csubvendor.id\t\tpci 0x%04x\n", first, drv->subvendor & 0xffff);
      first = '&';
    }

    if(drv->subdevice != ~0) {
      fprintf(f, "%csubdevice.id\t\tpci 0x%04x\n", first, drv->subdevice & 0xffff);
      first = '&';
    }

    fprintf(f, "+driver.module.modprobe\t%s\n", drv->name);

    fclose(f);
  }

  if((f = fopen("/etc/newids", "a"))) {
    fprintf(f, "%s,%s", print_driverid(drv, 1), drv->name ?: "");
    if(drv->sysfs_name) fprintf(f, ",%s", drv->sysfs_name);
    fprintf(f, "\n");

    fclose(f);
  }
}


/*
 * Check if network device matches.
 *
 * Return:
 *   0: no match
 *   1: ok
 */
int match_netdevice(char *device, char *hwaddr, char *key)
{
  if(!key) return 0;

  if(
    (device && !fnmatch(key, device, 0)) ||
    (hwaddr && !fnmatch(key, hwaddr, 0))
  ) return 1;

  return 0;
}

char* util_chop_lf(char* str)
{
  int lfp = strlen(str)-1;
  if(str[lfp] == '\n') str[lfp]=0;
  return str;
}

int util_read_and_chop(char* path, char* dst, int dst_size)
{
  FILE* fp;
  fp=fopen(path,"r");
  if(!fp) return 0;
  if(!fgets(dst,dst_size,fp)) { fclose(fp); return 0; }
  util_chop_lf(dst);
  fclose(fp);
  return 1;
}


/*
 * Find text for locale, or 'en' if no locale matches.
 */
char *get_translation(slist_t *trans, char *locale)
{
  slist_t *sl;
  char *search_loc = NULL, *s;

  if(!trans || !locale) return NULL;

  locale = strdup(locale);

  strprintf(&search_loc, "lang=\"%s\"", locale);

  for(sl = trans; sl; sl = sl->next) {
    if(sl->key && strstr(sl->key, search_loc)) break;
  }

  if(!sl && (s = strchr(locale, '_'))) {
    *s = 0;
    strprintf(&search_loc, "lang=\"%s\"", locale);
    for(sl = trans; sl; sl = sl->next) {
      if(sl->key && strstr(sl->key, search_loc)) break;
    }
  }

  if(!sl && strcmp(locale, "en")) {
    strprintf(&search_loc, "lang=\"en\"");
    for(sl = trans; sl; sl = sl->next) {
      if(sl->key && strstr(sl->key, search_loc)) break;
    }
  }

  free(locale);
  free(search_loc);

  return sl ? sl->value : NULL;
}


int util_process_running(char *name)
{
  pid_t pid;
  struct dirent *de;
  DIR *d;
  char *s;

  if(!name) return 0;

  if(!(d = opendir("/proc"))) return 0;

  while((de = readdir(d))) {
    pid = strtoul(de->d_name, &s, 10);
    if(!*s && !strcmp(util_process_name(pid), name)) break;
  }

  closedir(d);

  return de ? 1 : 0;
}


/*
 * like system() but redirect stdout to stderr
 */
int system_log(char *cmd)
{
  char *buf = NULL;
  int i;

  if(!cmd) return 0;

  strprintf(&buf, "%s >&2", cmd);

  i = system(buf);

  free(buf);

  return i;
}


void read_iscsi_ibft()
{
  file_t *f0, *f;

  if(!util_check_exist("/sbin/iscsiadm")) return;

  system("/sbin/iscsiadm -m fw >/var/log/ibft");

  f0 = file_read_file("/var/log/ibft", kf_ibft);

  if(config.debug) {
    if(f0) {
      fprintf(stderr, "ibft values:\n");
      for(f = f0; f; f = f->next) {
        fprintf(stderr, "  %s=%s\n", f->key_str, f->value);
      }
    }
    else {
      fprintf(stderr, "no ibft\n");
    }
  }

  for(f = f0; f; f = f->next) {
    switch(f->key) {
      case key_ibft_hwaddr:
        str_copy(&config.netdevice, f->value);
        break;

      case key_ibft_ipaddr:
        name2inet(&config.net.hostname, f->value);
        net_check_address(&config.net.hostname, 0);
        break;

      case key_ibft_netmask:
        name2inet(&config.net.netmask, f->value);
        net_check_address(&config.net.netmask, 0);
        break;

      case key_ibft_gateway:
        name2inet(&config.net.gateway, f->value);
        net_check_address(&config.net.gateway, 0);
        break;

      case key_ibft_dns:
        name2inet(&config.net.nameserver[0], f->value);
        net_check_address(&config.net.nameserver[0], 0);
        break;

      default:
        break;
    }
  }
}


char *blk_ident(char *dev)
{
  char *type, *label, *size;
  static char *id = NULL;

  if(id) {
    free(id);
    id = NULL;
  }

  if(!dev) return id;

  if(!config.blkid.cache) blkid_get_cache(&config.blkid.cache, "/dev/null");

  type = blkid_get_tag_value(config.blkid.cache, "TYPE", dev);
  label = blkid_get_tag_value(config.blkid.cache, "LABEL", dev);
  size = blk_size_str(dev);

  if(!size) return id;

  asprintf(&id, "%s, %s%s%s", size, type ?: "no fs", label ? ", " : "", label ?: "");

  free(type);
  free(label);

  return id;
}


char *blk_size_str(char *dev)
{
  uint64_t size;
  static char *s = NULL, unit;

  if(s) {
    free(s);
    s = NULL;
  }

  size = blk_size(dev);

  unit = 'k';
  if(size >= (1000 << 10)) { unit = 'M'; size >>= 10; }
  if(size >= (1000 << 10)) { unit = 'G'; size >>= 10; }
  if(size >= (1000 << 10)) { unit = 'T'; size >>= 10; }
  if(size >= (1000 << 10)) { unit = 'P'; size >>= 10; }
  if(size >= (1000 << 10)) { unit = 'E'; size >>= 10; }
  if(size >= (1000 << 10)) { unit = 'Z'; size >>= 10; }
  if(size >= (1000 << 10)) { unit = 'Y'; size >>= 10; }

  if(size >= 10 * (1 << 10)) {
    size = (size + 512) >> 10;
    asprintf(&s, "%u %cB", (unsigned) size, unit);
  }
  else {
    size = ((10 * size) + 512) >> 10;
    asprintf(&s, "%u.%u %cB", ((unsigned) size) / 10, ((unsigned) size) % 10, unit);
  }
  
  return s;
}


uint64_t blk_size(char *dev)
{
  int fd;
  blkid_loff_t size;

  fd = open(dev, O_RDONLY | O_NONBLOCK);
  size = fd >= 0 ? blkid_get_dev_size(fd) : 0;
  close(fd);

  return size >= 0 ? size : 0;
}


/*
 * Update device list in config.hd_data (if udev got new events).
 */
void update_device_list(int force)
{
  static time_t last_time;
  struct stat sbuf;

  hd_hw_item_t hw_items[] = {
    hw_block, hw_network_ctrl, hw_network, 0
  };

  if(!config.hd_data) force = 1;

  if(stat("/dev/.udev/uevent_seqnum", &sbuf)) {
    force = 1;
  }
  else if(last_time != sbuf.st_mtime) {
    last_time = sbuf.st_mtime;
    force = 1;
  }

  if(!force) return;

  fprintf(stderr, "%sscanning devices\n", config.hd_data ? "re" : "");

  if(config.hd_data) {
    hd_free_hd_data(config.hd_data);
    free(config.hd_data);
  }

  config.hd_data = calloc(1, sizeof *config.hd_data);

  fix_device_names(hd_list2(config.hd_data, hw_items, 1));
}


/*
 * Create new tmp mountpoint.
 */
char *new_mountpoint()
{
  static char *buf = NULL;

  strprintf(&buf, "%smp_%04u", config.mountpoint.base, config.mountpoint.cnt++);
  mkdir(buf, 0755);

  return buf;
}


/*
 * Copy 'src_dir/src_file' to 'dst'.
 *
 * return:
 *   0: ok
 *   1: failed
 */
int util_copy_file(char *src_dir, char *src_file, char *dst)
{
  int err = 0;
  char *buf = NULL, *argv[3];

  if(!src_dir || !src_file || !dst) return 1;

  strprintf(&buf, "%s/%s", src_dir, src_file);

  if(util_check_exist(buf) == 'r') {
    unlink(dst);
    argv[1] = buf;
    argv[2] = dst;
    if(util_cp_main(3, argv)) {
      unlink(dst);
      err = 1;
    }
  }
  else {
    err = 1;
  }

  str_copy(&buf, NULL);

  return err;
}


/*
 * Return new download image name.
 */
char *new_download()
{
  static char *buf = NULL;

  strprintf(&buf, "%s/file_%04u", config.download.base, config.download.cnt++);

  return buf;
}


void util_clear_downloads()
{
  int i;
  char *buf = NULL;

  for(i = config.download.cnt; i-- > 0;) {
    strprintf(&buf, "%s/file_%04u", config.download.base, i);
    if(util_check_exist(buf)) unlink(buf);
  }

  str_copy(&buf, NULL);
}


void util_wait(const char *file, int line)
{
  if(!config.debugwait) return;

  fprintf(stderr, "%s(%d)\n", file, line);
  printf("%s(%d) ?", file, line);

  switch(getchar()) {
    case 'q':
      util_umount_all();
      util_clear_downloads();
      config.debugwait = 0;
      lxrc_end();
      exit(0);
      break;

    case 's':
      kbd_end(0);
      if(config.win) disp_cursor_on();
      if(!config.linemode) {
        printf("\033c");
        if(config.utf8) printf("\033%%G");
        fflush(stdout);
      }

      system("PS1='\\w # ' /bin/bash 2>&1");

      kbd_init(0);
      if(config.win) {
        disp_cursor_off();
        if(!config.linemode) disp_restore_screen();
      }

    default:
      break;
  }
}

void util_umount_all_devices ()
    {
    FILE *fd;
    char buffer [1000];
    char dir [1000];
    char *dirs [1000];
    int  nr_dirs = 0;
    int  i, j;

    fd = fopen ("/proc/mounts", "r");
    if (fd)
        {
        while (fgets (buffer, sizeof (buffer), fd))
            if (!strncmp (buffer, "/dev/", 5))
                {
                i = j = 0;
                while (buffer [i] != ' ') i++;
                i++;
                while (buffer [i] != ' ') dir [j++] = buffer [i++];
                dir [j] = 0;
                dirs [nr_dirs++] = strdup (dir);
                }

        fclose (fd);

        if (!nr_dirs) return;

        fprintf (stderr, "Trying to unmount %d directories:\n", --nr_dirs);

        /* we need to unmount in reverse order */

        do
            {
            if (dirs [nr_dirs])
                {
                if (dirs [nr_dirs][1])
        {
        fprintf (stderr, "Unmounting %s...\n", dirs [nr_dirs]);
        umount (dirs [nr_dirs]);
        }
    free (dirs [nr_dirs]);
                }
            }
        while (nr_dirs--);
        }
    }


void run_braille()
{
  hd_t *hd, *hd1;
  hd_data_t *hd_data = calloc(1, sizeof *hd_data);
  char *cmd = NULL;
  FILE *f;

  hd_data->debug = -1;

  printf("Activating usb devices...\n");
  fprintf(stderr, "Activating usb devices...\n");

  /* braille dev might need usb modules */
  util_load_usb();

  sleep(config.usbwait + 1);

  hd_list(hd_data, hw_usb, 1, NULL);
  load_drivers(hd_data, hw_usb);

  sleep(config.usbwait + 1);

  printf("detecting braille devices...\n");
  fprintf(stderr, "detecting braille devices...\n");

  hd = hd_list(hd_data, hw_braille, 1, NULL);

  if(config.debug) {
    f = fopen("/var/log/braille.log", "w");
    if(f) {
      fprintf(f, "%s\n", hd_data->log);
      for(hd1 = hd_data->hd; hd1; hd1 = hd1->next) {
        hd_dump_entry(hd_data, hd1, f);
      }
      hd_dump_entry(hd_data, hd, f);
      fclose(f);
    }
  }

  for(; hd; hd = hd->next) {
    if(
      hd->base_class.id == bc_braille &&        /* is a braille display */
      hd->unix_dev_name &&                      /* and has a device name */
      hd->device.name
    ) {
      break;
    }
  }

  if(hd) {
    str_copy(&config.braille.dev, hd->unix_dev_name);
    str_copy(&config.braille.type, hd->device.name);
  }
  else {
    str_copy(&config.braille.dev, NULL);
    str_copy(&config.braille.type, NULL);
  }

  hd_free_hd_data(hd_data);
  free(hd_data);

  if(config.braille.dev) {
    printf("%s: %s\n", config.braille.dev, config.braille.type);
    fprintf(stderr, "%s: %s\n", config.braille.dev, config.braille.type);

    if(util_check_exist("/etc/suse-blinux.conf") == 'r') {
      strprintf(&cmd,
        "sed -i -e 's#^brlname=.*#brlname=%s#; s#^brlport=.*#brlport=%s#' /etc/suse-blinux.conf",
        config.braille.type, config.braille.dev
      );

      if(config.debug) fprintf(stderr, "%s\n", cmd);
      system(cmd);

      str_copy(&cmd, NULL);

      system("/etc/init.d/brld start >&2");
      system("/etc/init.d/sbl start >&2");

      str_copy(&config.setupcmd, "inst_setup yast");

      LXRC_WAIT
    }
  }
}


void util_setup_udevrules()
{
  slist_t *rule;
  file_t *f, *f_mac, *f_name;
  FILE *ff;

  for(rule = config.udevrules; rule; rule = rule->next) {
    f = file_parse_buffer(rule->key, kf_comma + kf_none);
    if(
      (f_mac = file_getentry(f, "mac")) &&
      (f_name = file_getentry(f, "name"))
    ) {
      fprintf(stderr, "udev net rule: mac = \"%s\", name = \"%s\"\n", f_mac->value, f_name->value);
      if((ff = fopen("/etc/udev/rules.d/70-persistent-net.rules", "a"))) {
        fprintf(ff,
          "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"%s\", ATTR{type}==\"1\", KERNEL==\"eth*\", NAME=\"%s\"\n",
          f_mac->value,
          f_name->value
        );
        fclose(ff);
      }
    }
    file_free_file(f);
  }
}


void util_error_trace(char *format, ...)
{
  va_list args;

  if(!config.error_trace) return;

  va_start(args, format);
  vfprintf(stderr, format, args);
  va_end(args);
  
  void *buffer[100];
  int nptrs;
  nptrs = backtrace(buffer, 100);
  backtrace_symbols_fd(buffer, nptrs, STDERR_FILENO);
}


/*
 * Change device names to match requested naming scheme.
 */
hd_t *fix_device_names(hd_t *hd)
{
  hd_t *hd0 = hd;
  str_list_t *sl, *sl0;
  char *s = NULL;

  if(!config.namescheme || !*config.namescheme) return hd0;

  asprintf(&s, "/%s/", config.namescheme);

  for(; hd; hd = hd->next) {
    if(!hd->unix_dev_name || !hd->unix_dev_names) continue;

    if(strstr(hd->unix_dev_name, s)) continue;

    for(sl = hd->unix_dev_names; sl; sl = sl->next) {
      if(strstr(sl->str, s)) {
        sl0 = calloc(1 , sizeof *sl0);
        sl0->next = hd->unix_dev_names;
        hd->unix_dev_names = sl0;
        sl0->str = strdup(sl->str);
        // ########## FIXME: should be freed
//        free(hd->unix_dev_name);
        hd->unix_dev_name = strdup(sl->str);
        break;
      }
    }
  }

  free(s);

  return hd0;
}
CODE_END
# -------------------------------------------------------------------------------------- #


end
