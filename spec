#!/bin/ksh

# Function to display the usage of the script in French
show_usage() {
    echo "Utilisation: $0 <Path Projet> <Produit>"
    echo "Exemple:"
    echo "  $0 /app/list/sd/sid/dev1/ sepa"
}

# Function for setting Vertica environment, adapt as needed
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

# Function to process and clean the file
function process_file {
    fichier_entree="$1"
    GpPathProjet="$2"
    Produit="$3"
    valid_delimiter_count=20  # Set based on expected structure
    custom_delimiter=";"  # Assuming semicolon as default

    # Define output files
    valid_file="${GpPathProjet}/entree/valid_$(basename "${fichier_entree}")"
    invalid_file="${GpPathProjet}/entree/invalid_$(basename "${fichier_entree}")"
    current_date=$(date +%Y-%m-%d)

    >"${valid_file}"
    >"${invalid_file}"

    # Process file and classify lines as valid or invalid
    awk -F"${custom_delimiter}" -v valid_count="${valid_delimiter_count}" -v date="${current_date}" -v filename="$(basename "${fichier_entree}")" -v tablename="HelloMohamed" '{
        if(NF-1 == valid_count) {
            print $0 >> "'${valid_file}'"
        } else {
            print NR, $0, filename, date, tablename >> "'${invalid_file}'"
        }
    }' OFS="|" "${fichier_entree}"

    echo "File processed: ${fichier_entree}"
    echo "Valid lines saved to: ${valid_file}"
    echo "Invalid lines saved to: ${invalid_file}"

    # Insert invalid lines into Vertica, assuming invalid_file is formatted correctly for bulk load
    if [[ -s "${invalid_file}" ]]; then
        gestion_vertica
        # Replace the below with your actual Vertica vsql command to load ${invalid_file}
        echo "Attempting to insert invalid lines into Vertica..."
        /opt/vertica/bin/vsql -U your_user -w your_password -h your_host -d your_database -c "COPY your_table FROM LOCAL '${invalid_file}' DELIMITER '|' DIRECT;"
        echo "Vertica insertion completed."
    fi

    # Optionally, remove valid and invalid files after processing
    rm -f "${valid_file}" "${invalid_file}"
}

# Validate input arguments
if [[ $# -ne 2 ]]; then
    show_usage
    exit 1
fi

GpPathProjet="$1"
Produit="$2"

# Example loop to process files - adjust as needed
# Assuming files to process are located in a specific directory
for fichier_entree in $(find "${GpPathProjet}/${Produit}/data/" -type f); do
    echo "Processing file: ${fichier_entree}"
    process_file "${fichier_entree}" "${GpPathProjet}" "${Produit}"
done
