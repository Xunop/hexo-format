#!/bin/sh

DATE=$(date +%Y-%m-%d)
TITLE=""
# hexo source directory
SOURCE_DIR="../source/_posts"
# note directory
NOTE_DIR="../notes"
# article description
DESC=""
# article head line
yhln=0
# head info
head_info=""

function handle_error {
  echo "\033[31mError:\033[0m $1" >&2
  exit 1
}

function help {
  echo "Usage: $(basename "$0") [OPTIONS]"
  echo "  OPTIONS:"
  echo "    -s, --source-dir DIR   Specify the source directory (default: '../source/_posts')"
  echo "    -n, --note-dir DIR     Specify the note directory (default: '../notes')"
  echo "    -h, --help             Display this help message and exit"
  echo ""
  echo "This script traverses the specified note directory and converts each Markdown file"
  echo "into a Jekyll-compatible format by inserting a \"<!-- more -->\" tag after the sixth line."
  echo "The converted files are then saved to the specified source directory."
  echo ""
  echo "Example:"
  echo "  $(basename "$0") --source-dir '../myblog/_posts' --note-dir '../myblog/notes'"
}

function parse_args {
  while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
      -s|--source-dir)
        SOURCE_DIR="$2"
        shift 2
        ;;
      -n|--note-dir)
        NOTE_DIR="$2"
        shift 2
        ;;
      -h|--help)
        help
        exit 0
        ;;
      *)
        echo "Error: Unrecognized option $key. Use --help to see the usage." >&2
        exit 1
        ;;
    esac
  done
}

# get description
function get_desc {
    # get article desc
    # desc is not '#' for the first two lines of the article
    DESC=$(sed -n "${yhln},20{/^#/p}" "$1" | sed -n '1,2p')
    echo "desc: $DESC"
}

# determine if a description is required
function is_desc {
    lcount=$(sed -n '1,20{/^#/p}' $1 | wc -l)
    # if the number of lines starting with '#' is greater than 2, it is considered that there is a description
    if [ $lcount -ge 2 ]; then
        return 0
    else
        return 1
    fi
}

# TODO
# generate head info
function gen_head_info {
    # get article date
    date=$(sed -n '1,20{/^date:/{p;q}}' "$1" | awk '{ print $2}')
    if [ -z "$date" ]; then
        date=$DATE
    fi
    # get article title
    TITLE=$(sed -n '1,20{/^[#][^#]/p}' "$1" | awk '{print $2}')

    # determine if there is need a description
    if is_desc "$1"; then
        get_desc "$1"
        TITLE=$(sed -n '1,20{/^[#][^#]/p}' "$1" | awk '{print $2}')
    fi

    # generate head info
    head_info="---\ndate: ${date}\ntitle: ${TITLE}\ndescription: ${DESC}\n---"
}

function peocess_file {
    # check if file exists
    if [ ! -f "$1" ]; then
        handle_error "File $1 does not exist"
    fi
    
    dir=$(dirname "$1" | xargs basename)
    filename=$(basename "$1")
    # insert '<!-- more -->' before line 6
    ln=6
    # article date
    date=$DATE
    # first line is '---'
    if head -n 1 "$1" | grep -q "^---$"; then
        # get line number of second '---'
        yhln=$(sed -n '2,20{/^---/{=;q}}' "$1")
        ln=$((yhln+6))
        # get article date
        date=$(sed -n '1,20{/^date:/{p;q}}' test.md | awk '{ print $2}')
        if [ -z "$date" ]; then
            date=$DATE
        fi
    fi

    # check if the line is a block
    hline=$(sed -n '1,20{/^```/{=;q}}' $1)
    if [ -n "$hline" ]; then
        if [ $ln -gt $hline ]; then
            tline=$(sed -n "$((hline+1)),20{/^\`\`\`/{=;q}}" $1)
            if [ -n "$tline" ]; then
                if [ $ln -lt $tline ]; then
                    ln=$hline
                elif [ $ln == $tline ]; then
                    ln=$((ln+1))
                fi
            fi
        fi
    fi

    # determine if there is need a description
    if is_desc "$1"; then
        get_desc "$1"
        TITLE=$(sed -n '1,20{/^[#][^#]/p}' "$1" | awk '{print $2}')
        # remove '<!--more-->' & remove titles that start with '#' but not '##...'
        sed '1,20{/<!-- more -->/d}' "$1" | sed '1,20{/^[#][^#]/d}' "$1" \
        sed "1i ---\ndate: ${date}\ntitle: ${TITLE}\ndescription: ${DESC}---" "$1" \
        > $SOURCE_DIR/$dir/$filename || handle_error "Could not write file $SOURCE_DIR/$dir/$filename"
        return
    fi

    
     
    # determine if the string "<!-- more -->" exists in the first 20 lines
    # generally do not exist
    if sed -n '1,20{/<!-- more -->/p}' "$1" | grep -q '^<!-- more -->$'; then
        if [ ! -d $SOURCE_DIR/$dir ]; then
            echo "--> create folder $SOURCE_DIR/$dir"
            mkdir -p $SOURCE_DIR/$dir || handle_error "Could not create folder $SOURCE_DIR/$dir"
        fi
        # remove '<!--more-->'
        # insert '<!-- more -->'
        # remove titles that start with '#' but not '##...'
        # write to file
        sed '1,20{/<!-- more -->/d}' "$1" | sed "${ln}i <!-- more -->" "$1" | sed '1,20{/^[#][^#]/d}' "$1" > $SOURCE_DIR/$dir/$filename || handle_error "Could not write file $SOURCE_DIR/$dir/$filename"
        echo "--> saved $SOURCE_DIR/$dir/$filename"
    else
        # insert '<!-- more -->'
        sed "${ln}i <!-- more -->" "$1" | sed '1,20{/^[#][^#]/d}' "$1" > $SOURCE_DIR/$dir/$filename || handle_error "Could not write file $SOURCE_DIR/$dir/$filename"
    fi
}


function traverse_folder {
    for file in "$1"/*; do
        if [ -d "$file" ]; then
            echo "traversing folder $file"
            traverse_folder "$file"
        elif [ "${file##*.}" = "md" ]; then
            if [ "$(basename "$file")" == "README.md" ]; then
                continue
            fi
            echo "processing file $file"
            peocess_file "$file"
        fi
    done
}

traverse_folder $NOTE_DIR
