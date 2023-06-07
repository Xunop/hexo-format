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
yhln=1
# head info
head_info=""
# parse all
ALL=0
# parse file
FILE=""


# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Define functions for printing colored output
print_error () {
  printf "${RED}[ERROR] ${1}${NC}\n"
}

print_info () {
  printf "${GREEN}[INFO] ${1}${NC}\n"
}

print_warning () {
  printf "${YELLOW}[WARNING] ${1}${NC}\n"
}

function handle_error {
  print_error "$1" at $2 >&2
  exit 1
}

function help {
  echo "Usage: $(basename "$0") [OPTIONS]"
  echo "  OPTIONS:"
  echo "    -s, --source-dir DIR   Specify the source directory (default: '../source/_posts')"
  echo "    -n, --note-dir DIR     Specify the note directory (default: '../notes')"
  echo "    -a, --all              Parse all files in the note directory (default: true)"
  echo "    -f, --file FILE        Parse the specified file in the note directory (default: '')"
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
      -a|--all)
        ALL="$2"
        shift
        ;;
      -f|--file)
        FILE="$2"
        shift 2
        ;;
      -h|--help)
        help
        exit 0
        ;;
      *)
        print_error "Error: Unrecognized option $key. Use --help to see the usage." >&2
        exit 1
        ;;
    esac
  done
}

# get description
function get_desc {
    # if there is not a head info
    if [ $yhln == 1 ]; then
        # del lines start with '```' and end with '```'
        DESC=$(sed -e '1,40{/```/,/```/{//!d;}}' "$1" \
            | sed '/\[\|\!\[/d' \
            | sed -n '1,20{/^[^#\`]/p}' \
            | sed -n '1,2p')
    else
        # get article desc
        # desc is not '#' $ '`' for the first two lines of the article
        DESC=$(sed -e '1,40{/```/,/```/{//!d;}}' "$1" \
            | sed '/\[\|\!\[/d' \
            | sed -n "$((yhln+1)),20{/^[^#\`]/p}" \
            | sed -n '1,2p')
    fi
    # replace '\' and '"' and '*' and '~' and '>'
    DESC=$(echo $DESC | sed 's/\\/\\\\/g; s/\"/\\\"/g; s/\*//g; s/\~//g; s/>//g; s/:/\":\"/g')
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

# generate head info
function gen_head_info {
    # get article title
    TITLE=$(sed -n '1,20{/^[#][^#]/p}' "$1" | awk '{print $2}')
    # DESC is not empty
    if [ -n "$DESC" ]; then
        # generate head info
        head_info="---\ndate: ${DATE}\ntitle: ${TITLE}\ndescription: ${DESC}\n---"
    else
        head_info="---\ndate: ${DATE}\ntitle: ${TITLE}\n---"
    fi
    # replace '\' and '"'
    head_info=$(echo $head_info | sed 's/\\/\\\\/g' | sed 's/\"/\\\"/g')
}

# 1. check if the file exists
# 2. determine if there is need a description
# 3. or insert '<!-- more -->' before line 6
# 4. write to file
function peocess_file {
    # check if file exists
    if [ ! -f "$1" ]; then
        handle_error "File $1 does not exist" $LINENO
    fi
    
    # insert '<!-- more -->' before line 6
    ln=6
    dir=$(dirname "$1" | xargs basename)
    filename=$(basename "$1")
    TITLE=$(sed -n '1,20{/^[#][^#]/p}' "$1" | awk '{print $2}')
    if [ ! -d $SOURCE_DIR/$dir ]; then
        print_info "--> create folder $SOURCE_DIR/$dir"
        mkdir -p $SOURCE_DIR/$dir || handle_error "Could not create folder $SOURCE_DIR/$dir" $LINENO
    fi

    # first line is '---'
    if head -n 1 "$1" | grep -q "^---$"; then
        # get line number of second '---'
        # if there is not a '---', yhln=1
        yhln=$(sed -n '2,20{/^---/{=;q}}' "$1")
        ln=$((yhln+6))
    fi
    
    # no head info
    if [ $yhln == 1 ]; then
        print_info "this article has no head info, generate head info"
        gen_head_info "$1"
    fi
    # determine if there is need a description
    if is_desc "$1"; then
        print_info "this article need a description"
        get_desc "$1"
        # head_info is empty
        # this article has head info
        if [ -z "$head_info" ]; then
            # DESC is not empty
            if [ -n "$DESC" ]; then
                sed "1a description: $DESC" "$1" > $SOURCE_DIR/$dir/$filename \
                    || handle_error "Could not write file $SOURCE_DIR/$dir/$filename" $LINENO
                                    return
            fi
        else
            sed "1i $(echo -e $head_info)" "$1" \
                > $SOURCE_DIR/$dir/$filename || handle_error "Could not write file $SOURCE_DIR/$dir/$filename" $LINENO
            head_info=""
            # DESC is not empty then return
            if [ -n "$DESC" ]; then return; fi
        fi
    fi
    
    echo -e "$head_info"
    # insert head info
    if [ -n "$head_info" ]; then
        sed "1i $(echo -e $head_info)" "$1" > "temp" || handle_error "Error $SOURCE_DIR/$dir/$filename" $LINENO
    fi
    
    print_info "oh! $SOURCE_DIR/$dir/$filename is need a <!-- more -->"

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
     
    # determine if the string "<!-- more -->" exists in the first 20 lines
    # generally do not exist
    if sed -n '1,20{/<!-- more -->/p}' "$1" | grep -q '^<!-- more -->$'; then
        # remove '<!--more-->'
        # insert '<!-- more -->'
        # remove titles that start with '#' but not '##...'
        # write to file
        
        if [ -n "$head_info" ]; then
            sed '1,20{/<!-- more -->/d}' "$1" | sed "${ln}i \\\n<!-- more -->" | sed '1,20{/^[#][^#]/d}' | sed "1i $(echo -e $head_info)" > $SOURCE_DIR/$dir/$filename \
                || handle_error "Could not write file $SOURCE_DIR/$dir/$filename" $LINENO
        else
            sed '1,20{/<!-- more -->/d}' "$1" | sed "${ln}i \\\n<!-- more -->" | sed '1,20{/^[#][^#]/d}' > $SOURCE_DIR/$dir/$filename \
                || handle_error "Could not write file $SOURCE_DIR/$dir/$filename" $LINENO
        fi
        print_info "--> saved $SOURCE_DIR/$dir/$filename"
    else
        print_info "--> insert <!-- more --> to $SOURCE_DIR/$dir/$filename"
        
        if [ -n "$head_info" ]; then
            # insert '<!-- more -->'
            sed "${ln}i \\\n<!-- more -->" "$1" | sed '1,20{/^[#][^#]/d}' | sed "1i $(echo -e $head_info)" > $SOURCE_DIR/$dir/$filename \
                || handle_error "Could not write file $SOURCE_DIR/$dir/$filename" $LINENO
        else
            sed "${ln}i \\\n<!-- more -->" "$1" | sed '1,20{/^[#][^#]/d}' | > $SOURCE_DIR/$dir/$filename \
                || handle_error "Could not write file $SOURCE_DIR/$dir/$filename" $LINENO
        fi
    fi
}

function traverse_folder {
    for file in "$1"/*; do
        if [ -d "$file" ]; then
            print_info "traversing folder $file"
            traverse_folder "$file"
        elif [ "${file##*.}" = "md" ]; then
            if [ "$(basename "$file")" == "README.md" ]; then
                continue
            fi
            print_info "processing file $file"
            peocess_file "$file"
        fi
    done
}

# specify a file
function specify_file {
    if [ ! -f "$1" ]; then
        handle_error "File $1 does not exist" $LINENO
    fi
    peocess_file "$1"
}

# main
parse_args "$@"

print_info "NOTE_DIR: $NOTE_DIR; SOURCE_DIR: $SOURCE_DIR"
if [ -n "$FILE" ]; then
    specify_file "$FILE"
else
    traverse_folder $NOTE_DIR
fi
