function copy-as-org
    pbpaste | pandoc -f gfm -t org | pbcopy
end
