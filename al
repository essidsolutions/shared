#!/bin/ksh

# Function to display the usage of the script in French
show_usage() {
    echo "Utilisation: $0 [-count] [-clean <nombre_delimiteurs_valides>] [-vertica] [-removeorigin] [-delimiter <delimiter>] <fichier_entree>"
    echo "Options:"
    echo "  -count                 Compter les lignes et les délimiteurs dans le fichier."
    echo "  -clean                 Nettoyer le fichier en fonction du nombre de délimiteurs, en conservant uniquement les lignes avec le nombre spécifié."
    echo "  -vertica               Insérer les enregistrements dans la table Vertica pour les lignes rejetées."
    echo "  -removeorigin          Supprimer le fichier original après le traitement."
    echo "  -delimiter             Spécifier le délimiteur utilisé dans le fichier (par défaut, ';')."
    echo "Exemple:"
    echo "  $0 -clean 5 -vertica -removeorigin -delimiter ';' mon_fichier.csv"
}



count_flag=0
clean_flag=0
vertica_flag=0
remove_origin_flag=0
valid_delimiter_count=0
custom_delimiter=";" # Default delimiter
FULLFILENAME=""
total_valid_lines=0
total_rejected_lines=0

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
    -h | --help)
        show_usage
        exit 0
        ;;
    -count)
        count_flag=1
        shift
        ;;
    -clean)
        clean_flag=1
        shift
        valid_delimiter_count="$1"
        shift
        ;;
    -vertica)
        vertica_flag=1
        shift
        ;;
    -removeorigin)
        remove_origin_flag=1
        shift
        ;;
    -delimiter)
        shift
        custom_delimiter="$1"
        shift
        ;;
    *)
        FULLFILENAME="$1"
        shift
        ;;
    esac
done

# Check if the input file is provided and exists
if [[ -z "$FULLFILENAME" || ! -f "$FULLFILENAME" ]]; then
    echo "Erreur : Fichier d'entrée non fourni ou n'existe pas."
    show_usage
    exit 1
fi

###################################################################################
#       Fonction Gestion de l'encodage Vertica
###################################################################################

function gestion_vertica {
    export LANG="en_US.UTF-8"
    export LC_COLLATE="en_US.UTF-8"
    export LC_CTYPE="en_US.UTF-8"
    export LC_MONETARY="en_US.UTF-8"
    export LC_NUMERIC="en_US.UTF-8"
    export LC_TIME="en_US.UTF-8"
    export LC_MESSAGES="en_US.UTF-8"
    export LC_ALL="en_US.UTF-8"
}
##########################################################################
# Insertion des lignes rejetees dans la table T_APP_REJ_ODS_GLOBAL #
##########################################################################

# Function to insert rejected lines into the Vertica table
insert_rejected_line() {
    if [[ $vertica_flag -eq 1 ]]; then
        local rejected_line="$1"
        gestion_vertica

        ${GpVsql}vsql -h ${GsDWHbaseHostsql} -B ${backup} -U ${GsDWHbaseUser} -w ${GsDWHbasepswd} -t -c "INSERT INTO $GsDWHbaseSchema.T_APP_REJ_ODS_GLOBAL VALUES (E'${rejected_line//\'/\'\'}');commit;"
        QUERY_RESULT=$?
        # Erreur si la requ¦te ne renvoie rien
        if [ "$QUERY_RESULT" == "" ]; then
            echo "ERREUR: La mise ¦ jour de la table T_APP_REJ_ODS_GLOBAL avec les lignes rejetees a echoue (${QUERY_RESULT})"
        fi
        echo $(date +"%Y-%m-%d %H:%M:%S")
        echo "les lignes rejetees ont ete mise a jour dans la table T_APP_REJ_ODS_GLOBAL correctement"

    fi
    ((total_rejected_lines++))
}

typeset -A delimiter_counts

process_delimiter() {
    # Loop through files matching the pattern
    while IFS= read -r line; do
        # Count the number of delimiters in the current line
        count=$(echo "$line" | awk -F"$custom_delimiter" '{print NF-1}')

        # Increment the count for this number of delimiters
        ((delimiter_counts[$count]++))

    done <"$FULLFILEPATH"

}

if [[ $count_flag -eq 1 ]]; then
    process_delimiter
    echo "[+] Counting lines and delimiters in $FULLFILENAME:"

    lineCount=$(wc -l <"$FULLFILENAME")
    echo "[+] The File $FULLFILENAME has $lineCount Total Lines"

    # Output the results
    echo "[+] Delimiter count results for file: $FULLFILENAME:"
    for delimiter in "${!delimiter_counts[@]}"; do
        echo "$delimiter delimiter : ${delimiter_counts[$delimiter]} lines"
    done
else
    echo "Pour savoir comment cela fonctionne : -h"

fi

# Function to process the file based on flags
process_file() {
    mkdir -p okfile
    OUTPUT_FILE="okfile/$(basename "$FULLFILENAME")"
    >"$OUTPUT_FILE"

    while IFS= read -r line; do
        count=$(echo "$line" | awk -F"$custom_delimiter" '{print NF-1}')
        if [[ $count -eq $valid_delimiter_count ]]; then
            echo "$line" >>"$OUTPUT_FILE"
            ((total_valid_lines++))
        else
            insert_rejected_line "$line"
        fi
    done <"$FULLFILENAME"

    if [[ $remove_origin_flag -eq 1 ]]; then
        rm -f "$FULLFILENAME"
    fi

    echo "Fichier nettoyé enregistré dans $OUTPUT_FILE"
    echo "Lignes valides : $total_valid_lines"
    echo "Lignes rejetées : $total_rejected_lines"
}

# Call the process_file function
if [[ $clean_flag -eq 1 ]]; then
process_file
fi
