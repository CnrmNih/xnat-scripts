initialize() {
    [[ $# != 6 ]] || { showHelp; exit -1; }
    [[ -z WORK ]] || { WORK=$(echo ~)/xnat/$(date +%Y%m%d%H%M%S); echo Setting work folder to ${WORK}.; }
    [[ -e ${WORK} ]] || { mkdir -p ${WORK}; }
    echo ADDRESS=${1} > ${WORK}/vars.sh
    echo USER=${2}    >> ${WORK}/vars.sh
    echo FOLDER=${3}  >> ${WORK}/vars.sh
    echo PROJECT=${4} >> ${WORK}/vars.sh
    echo SUBJECT=${5} >> ${WORK}/vars.sh
    echo SESSION=${6} >> ${WORK}/vars.sh
    source ${WORK}/vars.sh
}

showHelp() {
    echo Proper usage: xnatimport XNAT_URL XNAT_USER FOLDER PROJECT SUBJECT SESSION
}

# Creates the cookie file containing validated JSESSIONID.
authenticate() {
    STATUS=$(curl --cookie ${WORK}/cookies.txt -s -o /dev/null -w "%{http_code}" ${ADDRESS}/data/projects)
    if [[ ${STATUS} == 401 ]]; then
        STATUS=$(curl --cookie-jar ${WORK}/cookies.txt --user ${USER} -s -o /dev/null -w "%{http_code}" ${ADDRESS}/data/projects)
        if [[ ${STATUS} != 200 ]]; then
            echo There was an error with your username or password. Return code: ${STATUS}.
            exit -1
        fi
    fi
}

walkFolder() {
    for SESSION in $(find ${FOLDER} -mindepth 1 -maxdepth 1 -type d); do
        echo Found session folder $(basename ${SESSION})
        for SERIES in $(find ${SESSION} -mindepth 1 -maxdepth 1 -type d); do
            TARGET=${WORK}/$(basename ${SESSION})-$(basename ${SERIES})
            zip ${TARGET}.zip $(find ${SERIES} -type f -name *.dcm)
            sendDICOMScanToXNAT
        done
        commitSessionToXNAT
    done
}

# Send the DICOM scan stored in the indicated zip file to the specified XNAT server.
sendDICOMScanToXNAT() {
    STATUS=$(curl --cookie ${WORK}/cookies.txt --request POST --output ${TARGET}.txt -w "%{http_code}" --form "file=@${TARGET}.zip" "${ADDRESS}/data/services/import?import-handler=DICOM-zip&PROJECT_ID=${PROJECT}&SUBJECT_ID=${SUBJECT}&EXPT_LABEL=${SESSION}&rename=true&prevent_anon=true&prevent_auto_commit=true&autoArchive=true&SOURCE=script")
    if [[ ${STATUS} != 200 ]]; then
        echo An error occurred while sending ${TARGET}. Status code ${STATUS}, output: $(cat ${TARGET}.txt)
    fi
}

commitSessionToXNAT() {    
    CAPTURE=$(cat ${TARGET}.txt | tr -d '\r')
    curl --cookie ${WORK}/cookies.txt --request POST "${ADDRESS}${CAPTURE}?action=commit&SOURCE=script"
}

