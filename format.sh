#!/bin/sh

DEBUG=0
FORCE=0
DATE=$(date +%Y-%m-%d)
UPDATED=""
TITLE=""
TAGS=""
CATEGORY=""
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
  #printf "${RED}[ERROR] ${1}${NC}\n"
  echo -e "${RED}[ERROR] ${1}${NC}\n"
}

print_info () {
  #printf "${GREEN}[INFO] ${1}${NC}\n"
  echo -e "${GREEN}[INFO] ${1}${NC}\n"
}

print_warning () {
  #printf "${YELLOW}[WARNING] ${1}${NC}\n"
  echo -e "${YELLOW}[WARNING] ${1}${NC}\n"
}

handle_error () {
  print_error "$1" at $2 >&2
  exit 1
}

help () {
  echo "Usage: $(basename "$0") [OPTIONS]"
  echo "  OPTIONS:"
  echo "    -s, --source-dir DIR   Specify the source directory (default: '../source/_posts')"
  echo "    -n, --note-dir DIR     Specify the note directory (default: '../notes')"
  echo "    -a, --all              Parse all files in the note directory (default: true if not specify -f, false if specify -f)"
  echo "    -f, --file FILE        Parse the specified file in the note directory (default: '')"
  echo "    --force                Force to parse the specified file (default: false), can reset tags and description and title"
  echo "    -h, --help             Display this help message and exit"
  echo ""
  echo "This script traverses the specified note directory and converts each Markdown file"
  echo "into a Jekyll-compatible format by inserting a \"<!-- more -->\" tag after the sixth line."
  echo "The converted files are then saved to the specified source directory."
  echo ""
  echo "Example:"
  echo "  $(basename "$0") --source-dir '../myblog/_posts' --note-dir '../myblog/notes'"
}

parse_args () {
  while [ $# -gt 0 ]; do
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
        # while [[ $# -gt 0 && ! "$1" =~ ^-[^-] ]]; do
        #   FILE="$FILE $1"
        #   shift
        # done
        ;;
      --force)
        FORCE=1
        shift
        ;;
      -d|--delete)
        del_file "$2"
        shift
        ;;
      --debug)
        DEBUG=1
        shift
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

# replace '\' and '"' and '*' and '~' and '>'
replace() {
    $1=$(sed 's/\\/\\\\/g; s/\"/\\\"/g; s/\*//g; s/\~//g; s/>//g; s/:/\":\"/g' "$1")
}

# get description
get_desc () {
    # del lines start with '```' and end with '```'
    # del lines container '[' or '![', because it is a picture or a link
    tmp=$(sed -n '1,20 { /```/,/```/d; s/`//g; /\[\|\!\[/d; p; }' "$1")
    DESC=$(echo "$tmp" | sed -n '/^#/,/^##/p;/^##/q' | sed '/#/d' | sed '/^$/d');
    if [ -z "$DESC" ]; then
        # get the first 15 lines not starting with '#' or '`'
        DESC=$(echo "$tmp" | sed -n '1,15{/^[^#\`]/p}' | sed -n '1,2p')
    fi
    DESC=$(echo "$DESC" | tr -d '\n')
    # replace '\' and '"' and '*' and '~' and '>'
    DESC=$(echo "$DESC" | sed 's/\\/\\\\/g; s/\"/\\\"/g; s/\*//g; s/\~//g; s/>//g; s/:/\":\"/g')
    # replace "$DESC"
}

# determine if a description is required
is_desc () {
    lcount=$(sed -n '1,15{/^#/p}' $1 | wc -l)
    # if the number of lines starting with '#' is greater than 2 in 1-10,
    # it is considered that there is a description
    if [ $lcount -ge 2 ]; then
        return 0
    else
        return 1
    fi
}

# get title
get_title () {
    TITLE=$(sed -n '1,10{/^[#][^#]/p}' "$1")
    TITLE=${TITLE: 2}
    if [ -z "$TITLE" ]; then
        TITLE=$(basename "$1")
    fi
}

# generate head info
gen_head_info () {
    # Get article title
    get_title "$1"
    # Determine head_info based on DESC and UPDATED
    if [ -z "$UPDATED" ]; then
        updated_line=""
    else
        updated_line="updated: ${UPDATED}\n"
    fi
    head_info="---\ndate: ${DATE}\n${updated_line}title: ${TITLE}"
    if [ -n "$DESC" ]; then
        head_info="${head_info}\ndescription: ${DESC}"
    fi
    if [ -n "$TAGS" ]; then
        head_info="${head_info}\ntags:\n"
        for tag in $TAGS; do
            head_info="${head_info}- ${tag}\n"
        done
    fi
    if [ -n "$CATEGORY" ]; then
        head_info="${head_info}\ncategories:\n- [${CATEGORY}]"
    fi
    head_info="${head_info}\n---"
    # Replace '\' and '"'
    head_info=$(echo "$head_info" | sed 's/\\/\\\\/g' | sed 's/\"/\\\"/g')
}

declare -A file_tags
read_tags() {
        if [ -f $1/tags ]; then
                print_info "read tags from $1/tags"
                while IFS= read -r line; do
                        tags_filename=$(echo $line | awk -F: '{print $1}')
                        tags=$(echo $line | awk -F: '{print $2}')
                        file_tags[$tags_filename]=$tags
                done < $1/tags
        else
                print_info "no tags file in $1"
        fi
}

insert_head_info () {
        # insert head info and write to file and del the line start with '#'
        sed "1i $(echo -e "$head_info")" "$1" | sed '/^[#][^#]/d' \
                > $SOURCE_DIR/$dir/$filename || handle_error "Could not write file $SOURCE_DIR/$dir/$filename"
        print_info "--> saved $SOURCE_DIR/$dir/$filename"
}

# 1. check if the file exists
# 2. determine if there is need a description
# 3. or insert '<!-- more -->' before line 7
# 4. write to file
peocess_file () {
    # check if file exists
    if [ ! -f "$1" ]; then
        handle_error "File $1 does not exist" $LINENO
    fi
    
    if [ "${1##*.}" != "md" ]; then
        return
    fi
    
    if [ "$(basename "$file")" = "README.md" ]; then
        return
    fi
    
    # insert '<!-- more -->' before line 6
    ln=7
    dir=$(dirname "$1" | xargs basename)
    CATEGORY=$dir
    print_info "current dir: $SOURCE_DIR/$dir"
    filename=$(basename "$1")
    print_info "current filename: $filename"

    read_tags $NOTE_DIR/$dir
    echo "filename: $filename"

    if [ ! -d $SOURCE_DIR/$dir ]; then
        print_info "--> create folder $SOURCE_DIR/$dir"
        mkdir -p $SOURCE_DIR/$dir || handle_error "Could not create folder $SOURCE_DIR/$dir" $LINENO
    elif [ -f $SOURCE_DIR/$dir/$filename ]; then
            if [ $FORCE -eq 1 ]; then
                    DATE=$(sed -n '1,10{/^date:/p}' $SOURCE_DIR/$dir/$filename | sed 's/date: //g')
                    TAGS=${file_tags[$filename]}
                    UPDATED=$(date +%Y-%m-%d)
                    get_desc "$1"
                    gen_head_info "$1"
                    insert_head_info "$1"
                    return
            fi

            DATE=$(sed -n '1,10{/^date:/p}' $SOURCE_DIR/$dir/$filename | sed 's/date: //g')
            DESC=$(sed -n '1,30{/^description:/p}' $SOURCE_DIR/$dir/$filename | sed 's/description: //g')
            TITLE=$(sed -n '1,30{/^title:/p}' $SOURCE_DIR/$dir/$filename | sed 's/title: //g')
            TAGS=$(head -n 30 $SOURCE_DIR/$dir/$filename | awk '/^tags:/ {tags=1; next} /^-[^-]/ && tags {print substr($0, 3); next} {tags=0}')
            TAGS+="${file_tags[$filename]}"
            # Remove duplicates
            TAGS=$(echo $TAGS | tr ' ' '\n' | sort -u | tr '\n' ' ')
            UPDATED=$(date +%Y-%m-%d)

            gen_head_info "$1"
            insert_head_info "$1"
            return
    fi

    TAGS=${file_tags[$filename]}
    get_desc "$1"
    
    # DESC is not empty
    if [ -n "$DESC" ]; then
        gen_head_info "$1"
        insert_head_info "$1"
        return
    fi
    
    # determine if there is need a description
   # if is_desc "$1"; then
   #     print_info "this article need a description"
   #     # head_info is empty
   #     # this article has head info
   #     if [ -z "$head_info" ]; then
   #         # DESC is not empty
   #         if [ -n "$DESC" ]; then
   #             sed "1a description: $DESC" "$1" > $SOURCE_DIR/$dir/$filename \
   #                 || handle_error "Could not write file $SOURCE_DIR/$dir/$filename" $LINENO
   #             return
   #         fi
   #     else
   #         sed "1i $(echo -e $head_info)" "$1" \
   #             > $SOURCE_DIR/$dir/$filename || handle_error "Could not write file $SOURCE_DIR/$dir/$filename" $LINENO
   #         head_info=""
   #         # DESC is not empty then return
   #         if [ -n "$DESC" ]; then return; fi
   #     fi
   # fi
    
    gen_head_info "$1"

    print_info "oh! "$1" is need a <!-- more -->"

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

del_file () {
    dfile=$SOURCE_DIR/$1
    if [ -f $dfile ]; then
        print_info "deleting file $dfile"
        mv $dfile "$dfile.trash"
    fi
}

traverse_folder () {
    for file in "$1"/*; do
        if [ -d "$file" ]; then
            print_info "traversing folder $file"
            traverse_folder "$file"
        elif [ "${file##*.}" = "md" ]; then
            if [ "$(basename "$file")" = "README.md" ]; then
                continue
            fi
            print_info "processing file $file"
            peocess_file "$file"
        fi
    done
}

# specify a file
specify_file (){
    if [ ! -f "$1" ]; then
        handle_error "File $1 does not exist" $LINENO
    fi
    peocess_file "$1"
}

### main ###
parse_args "$@"

if [ $DEBUG -eq 1 ]; then
        if [ -d 'debug' ]; then
                echo "debug folder exists"
        else
                mkdir debug
        fi
        SOURCE_DIR=$(pwd)/debug
fi

print_info "NOTE_DIR: $NOTE_DIR; SOURCE_DIR: $SOURCE_DIR"
if [ -n "$FILE" ] && [ -f "$FILE" ]; then
    specify_file "$FILE"
else
    traverse_folder $NOTE_DIR
fi
