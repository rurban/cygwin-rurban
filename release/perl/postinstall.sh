#!/bin/sh
# Force proper configuration dialog on first cpan invocation
# and use the cygwin path, not the windows one. 
# The default is # C:/Documents and Settings/$USER/.cpan, not ~/.cpan
if [ ! -d ~/.cpan/CPAN ]; then
    mkdir -p ~/.cpan/CPAN
    echo "1;" > ~/.cpan/CPAN/MyConfig.pm
fi

echo Remember to initialize your CPAN::Reporter profile with
echo metabase-profile and cpan
echo   o conf init test_report
