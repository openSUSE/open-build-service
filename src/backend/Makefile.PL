use ExtUtils::MakeMaker;
WriteMakefile(
    NAME         => 'BSSolv',
    VERSION_FROM => 'BSSolv.pm',
    INC          => '-Isat-solver/src -Isat-solver/ext',   # e.g., '-lm'
    LIBS         => ['-Lsat-solver/src -Lsat-solver/ext -lsatsolverext -lsatsolver -lz'],   # e.g., '-lm'
)
