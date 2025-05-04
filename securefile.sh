#!/bin/bash

# Function to display help menu
usage() {
    echo "securefile.sh is a bash script that can encrypt / decrypt a file using openssl"
    echo "Usage: $0 [OPTIONS] [FILENAME] [PASSPHRASE]"
    echo
    echo "Options:"
    echo "  --encrypt              Encrypts a file using AES-256."
    echo "  --decrypt              Decrypts an encrypted .enc file and displays its content."
    echo "  --decrypt --save       Decrypts .enc file and saves on disk the plaintext file."
    echo "  --decrypt --edit       Decrypts, edits (geany), and re-encrypts an encrypted file."
    echo "  --help                 Displays this help message."
    echo
    echo "[PASSPHRASE]: Your very own password phrase for encryption. You have to provide the same passphrase for decryption"
    echo "              Make sure to enclose your passphrase with single quotes, especially if special characters are used"
    echo
    echo "Rules:"
    echo "  - Encrypted files will use the '.enc' extension (e.g., myfile.txt will created myfile.txt.enc)."
    echo "  - Decryption only works on '.enc' files."
    echo "  - This script does not require root privileges but may need sudo for certain files."
    echo
    echo "Usage Examples:"
    echo "      ./securefile.sh --encrypt myfile.txt 'mypassphrase'"
    echo "      ./securefile.sh --decrypt myfile.txt.enc 'mypassphrase'"
    echo "      ./securefile.sh --decrypt --save myfile.txt.enc 'mypassphrase'"
    echo "      ./securefile.sh --decrypt --edit myfile.txt.enc 'mypassphrase'"    
    echo
    echo "TODO: "
    echo "  Expand this script to encrypt/decrypt all files in a directory"
    echo "  Modify the script to handle file in from directory A but output file B (encrypted / decrypted) to be stored in Directory B"
    echo
    exit 1
}

if ! command -v openssl &> /dev/null || ! command -v shred &> /dev/null || ! command -v geany &> /dev/null; then
    echo "Error: Required dependencies (OpenSSL, Shred, Geany) are missing!"
    exit 1
fi


# Check number of arguments
if [[ $# -lt 2 ]]; then
    usage
fi

# Initialize mode flags
ENCRYPT_MODE=false
DECRYPT_MODE=false
EDIT_MODE=false
SAVE_MODE=false
an="no"

# Loop through script arguments
for arg in "$@"; do
    case "$arg" in
        --encrypt)
            ENCRYPT_MODE=true
            ;;
        --decrypt)
            DECRYPT_MODE=true
            ;;
        --save)
            SAVE_MODE=true
            ;;
        --edit)
            EDIT_MODE=true
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            if [[ -z "$FILE" ]]; then
                FILE="$arg"  # Capture filename dynamically
                echo "Filename Captured: $FILE"
            elif [[ -z "$PASSPHRASE" ]]; then
                PASSPHRASE="$arg"  # Capture passphrase
                echo "passphrase captured: $PASSPHRASE"
            else
                echo "Error: Unrecognized option '$arg'"
                usage
                exit 1
            fi
            ;;
    esac
done

# Validate input file
if [[ -z "$FILE" || -z "$PASSPHRASE" ]]; then
    echo "Error: Both filename and passphrase are required."
    usage
    exit 1
fi

# Function to check encryption status
is_encrypted() {
    head -c 8 "$1" | grep -q "Salted__"
}

# Encrypt file
encrypt_file() {
    ENC_FILE="${FILE}.enc"
    if [[ "$FILE" == *.enc ]]; then
        echo "Error: Input file already appears to be encrypted!"
        exit 1
    fi
    echo "Encrypting '$FILE' -> '$ENC_FILE'..."
    openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 -in "$FILE" -out "$ENC_FILE" -pass pass:"$PASSPHRASE" && echo "Encryption successful!"
    read -p "Delete original file $FILE? [y|yes]: " an
    [[ $an == 'y' || $an == 'yes' ]] && shred -u "$FILE" && echo "$FILE deleted"
    #shred -u "$FILE"

}

# Decrypt file 
decrypt_file() {
    OUTPUT_FILE="${FILE%.enc}"
    if [[ ! "$FILE" == *.enc ]]; then
        echo "Error: Decryption requires a '.enc' file!"
        exit 1
    fi

    if ! is_encrypted "$FILE"; then
        echo "Error: This file does not appear to be encrypted!"
        exit 1
    fi

    if [[ $SAVE_MODE == "true" ]]; then 
    echo "Decrypting '$FILE' , saving to '$OUTPUT_FILE'..."
    openssl enc -aes-256-cbc -d -pbkdf2 -iter 100000 -in "$FILE" -out "$OUTPUT_FILE" -pass pass:"$PASSPHRASE" && echo "Decryption successful!"

    elif [[ $SAVE_MODE == "false" && $EDIT_MODE == "false" ]]; then 
    echo "Decrypting and displaying '$FILE'..."
    openssl enc -aes-256-cbc -d -pbkdf2 -iter 100000 -in "$FILE" -pass pass:"$PASSPHRASE"

    elif [[ $SAVE_MODE == "false" && $EDIT_MODE == "true" ]]; then
    TEMP_DIR="/tmp"
    ORIGINAL_DIR="$(dirname "$FILE")"
    TEMP_FILE="${TEMP_DIR}/$(basename "${FILE%.enc}")"
    REENCRYPTED_FILE="${ORIGINAL_DIR}/$(basename "$FILE")"
    
    echo "Decrypting and Editing file '$FILE' using temporary file '$TEMP_FILE'"
    #openssl enc -aes-256-cbc -d -pbkdf2 -iter 100000 -in "$FILE" -out "$OUTPUT_FILE" -pass pass:"$PASSPHRASE"
    openssl enc -aes-256-cbc -d -pbkdf2 -iter 100000 -in "$FILE" -out "$TEMP_FILE" -pass pass:"$PASSPHRASE" && echo "decrypting $FILE succesfull"
    #geany "$OUTPUT_FILE"
    geany "$TEMP_FILE"
    read -p "Make Sure that you have saved all changes and press Enter after finishing editing to re-encrypt $TEMP_FILE to $REENCRYPTED_FILE ..."
    echo "Re-encrypting temporary file $TEMP_FILE after editing to $REENCRYPTED_FILE ..."
    #openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 -in "$OUTPUT_FILE" -out "$FILE" -pass pass:"$PASSPHRASE" && echo "File successfully re-encrypted."
    openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 -in "$TEMP_FILE" -out "$REENCRYPTED_FILE" -pass pass:"$PASSPHRASE" && echo "File successfully re-encrypted."
    #read -p "Delete temp file $OUTPUT_FILE? [y|yes]: " an
    #[[ $an == 'y' || $an == 'yes' ]] && shred -u "$OUTPUT_FILE" && echo "$OUTPUT_FILE deleted"
    read -p "Delete temporary file $TEMP_FILE? [y|yes]: " an
    [[ $an == 'y' || $an == 'yes' ]] && shred -u "$TEMP_FILE" && echo "$TEMP_FILE deleted"
    fi
}

# Execute the selected action
# Prevent conflicting options
if [[ "$ENCRYPT_MODE" == true && "$DECRYPT_MODE" == true ]]; then
    echo "Error: Cannot use both --encrypt and --decrypt at the same time!"
    exit 1
fi

if [[ "$ENCRYPT_MODE" == true ]]; then
    echo "encrypt mode enabled"
    encrypt_file
elif [[ "$DECRYPT_MODE" == true ]]; then
    echo "decrypt mode enabled"
    decrypt_file
else
    usage
fi
