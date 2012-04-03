use ExtUtils::MakeMaker;
WriteMakefile(
    NAME         => 'BSSolv',
    VERSION_FROM => 'BSSolv.pm',
    INC          => '-Ilibsolv/src -Ilibsolv/ext -Ilibsolv/build/src',   # e.g., '-lm'
    LIBS         => ['-Llibsolv/src -Llibsolv/ext -Llibsolv/build/src -Llibsolv/build/ext -lsolvext -lsolv -lz -llzma'],   # e.g., '-lm'
)
