BEGIN {
    m = 0
}

/^[ 0-9]+free[ 0-9]+open[ 0-9]+done[ 0-9]+failed$/ {
    if($7 > m) {
        m = $7
    }
}

END {
    print m
}
