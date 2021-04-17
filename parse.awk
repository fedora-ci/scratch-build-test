BEGIN {
    d = 0
    f = 0
}

/^[ 0-9]+free[ 0-9]+open[ 0-9]+done[ 0-9]+failed$/ {
    d += $5
    f += $7
}

END {
    print (((d == 0) || (f > 0)) ? 1 : 0)
}
