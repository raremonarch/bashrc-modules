# custom, user defined bash functions

###
# openssl encrypt/decrypt files (password in bitwarden)
###
osenc_passfile=~/.openssl/password
function osenc_get_passfile() {
    if [ ! -f $osenc_passfile ]; then
        echo "Error: Password file ~/.password not found or inaccessible."
        return 1
    else
        return $(tr -d '\n' < $osenc_passfile)
    fi
}
function osenc() {
    if [ -z "$1" ]; then
        echo "Usage: osenc <file>"
        return 1
    fi
    if [ ! -f "$osenc_passfile" ]; then
        echo "Error: Password file $osenc_passfile not found or inaccessible."
        return 1
    fi
    openssl enc -aes-256-cbc -pbkdf2 -in "$1" -out "$1.enc" -pass file:"$osenc_passfile"
    mv "$1.enc" "$1"
}
function osdec() {
    if [ -z "$1" ]; then
        echo "Usage: osdec <file>"
        return 1
    fi
    if [ ! -f "$osenc_passfile" ]; then
        echo "Error: Password file $osenc_passfile not found or inaccessible."
        return 1
    fi
    openssl enc -aes-256-cbc -pbkdf2 -d -in "$1" -out "$1.tmp" -pass file:"$osenc_passfile"
    rm "$1";  mv "$1.tmp" "$1"
}
