#!/bin/bash
# ~/.bashrc.d/python.sh

function cdpydev () {
    cd /f/Development/Personal/Private/Python
}

function poetryreq () {
    cmd='poetry export -f requirements.txt --without-hashes'
    if [ -z ${1} ]; then
        cmd+=' -o requirements.txt'
        echo "$cmd"
        ${cmd}
    elif [ ${1} == "--dev" ]; then
        cmd1="${cmd} -o requirements.txt"
        cmd2="${cmd} -o requirements_dev.txt --with dev"
        echo "$cmd1"
        ${cmd1}
        echo "$cmd2"
        ${cmd2}
    fi
}

function pycov () {
    pytest --cov-report term-missing:skip-covered --cov=.
}

function pycov-all () {
    pytest --cov-report term-missing --cov=.
}

function coverage-check () {
    coverage report --fail-under=80 --show-missing
}