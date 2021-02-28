#!/usr/bin/env zsh

# override locale to eliminate parsing errors
export LC_ALL=C

dir=$(pwd)  # get current dir
f=ip.list   # result list file
f6=ip6.list # result list file only containing v6 addresses
f4=ip4.list # result list file only containing v4 addresses
i=1         # first page is 1
iso_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# overwrite contents of existing file
echo -n '' > $dir/$f

# loop over all pages until end is reached. Each page contains
# 100 results and contains a final anchors count, plus hint of
# the next page uri, if any. Else null.
while (($i > 0)) ; do
    # the ripe atlas api for getting anchor information. Store the
    # result locally in a json file.
    curl -snGL https://atlas.ripe.net/api/v2/anchors/\?page\=$i > $dir/anchors-$i.json

    # process the fetched result. Extract the ipv4 and
    # ipv6 addresses. Skip any that is null or starts
    # with "::".
    jq '.results[] |
        [.ip_v4,.ip_v6][] |
        select(. != null) |
        select(startswith("::") == false) |
        @text' \
        $dir/anchors-$i.json >> $dir/$f

    # check if there is a next page to fetch, otherwise
    # set i to -1 to break loop execution.
    if [[ $(jq '.next' $dir/anchors-$i.json) == null ]]; then
        i=-1
    else
        ((i+=1))
    fi
done

# remove quotation from result file
sed -i -e 's/^"//' -e 's/"$//' $dir/$f

# create the v6 and v4 only ip list files
grep "\:" $f > $f6
grep "\." $f > $f4

# computer checksums
sha256sum $f > $f.sha256
sha256sum $f6 > $f6.sha256
sha256sum $f4 > $f4.sha256

# commit latest version of files
git add $f $f.sha256
git add $f6 $f6.sha256
git add $f4 $f4.sha256
git commit -m "Updated $f - $iso_date" --quiet

# push repository to every remote configured
if [[ $(git remote | grep -vi upstream | wc -l) > 0 ]] ; then
    for remote in $(git remote | grep -vi upstream | paste -sd " " -) ; do
        git push $remote main:main --quiet
    done
fi
