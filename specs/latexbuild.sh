#!/bin/bash
SPEC=$1

if [ $SPEC -z ]
then
    SPECS=(btcrelay-spec polkabtc-spec)
else
    SPECS=($SPEC)
fi

for item in ${SPECS[*]}
do
    # build the latex files
    sphinx-build -b latex $item/docs/source $item/docs/build/latex

    # create the PDF
    make -C $item/docs/build/latex

    # open the specification
    nohup xdg-open $item/docs/build/latex/*.pdf &>/dev/null &
done