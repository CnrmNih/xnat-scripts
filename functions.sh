initialize() {
    [[ $# == 5 ]] || { echo Insufficient number of arguments: $#; showHelp; exit -1; }
    TIMESTAMP=$(date +%Y%m%d%H%M%S)
    [[ -z WORK ]] || { WORK=$(echo ~)/xnat/${TIMESTAMP}; echo Setting work folder to ${WORK}.; }
    [[ -e ${WORK} ]] || { mkdir -p ${WORK}; }
    ADDRESS=${1}
    USER=${2}
    FOLDER=${3}
    PROJECT=${4}
    SUBJECT=${5}
    echo User ${USER} is sending to ${ADDRESS} from the folder ${FOLDER}: project ${PROJECT}, subject ${SUBJECT}
}

showHelp() {
    echo Proper usage: xnatimport XNAT_URL XNAT_USER FOLDER PROJECT SUBJECT
}

# Creates the cookie file containing validated JSESSIONID.
authenticate() {
    STATUS=$(curl -s --cookie ${WORK}/.cookies -o /dev/null -w "%{http_code}" ${ADDRESS}/data/projects)
    if [[ ${STATUS} == 401 ]]; then
        STATUS=$(curl -s --cookie-jar ${WORK}/.cookies --user ${USER} -o /dev/null -w "%{http_code}" ${ADDRESS}/data/projects)
        if [[ ${STATUS} != 200 ]]; then
            echo There was an error with your username or password. Return code: ${STATUS}.
            exit -1
        fi
    fi
}

# Send the DICOM scan stored in the indicated zip file to the specified XNAT server.
sendScan() {
    URL="${ADDRESS}/data/services/import?import-handler=DICOM-zip&PROJECT_ID=${PROJECT}&SUBJECT_ID=${SUBJECT}&EXPT_LABEL=${SESSION}&rename=true&prevent_anon=true&prevent_auto_commit=true&autoArchive=true&SOURCE=script"
    STATUS=$(curl -s --cookie ${WORK}/.cookies --request POST --output ${SESSION_OUT} -w "%{http_code}" --form "file=@${TARGET}.zip" ${URL})
    if [[ ${STATUS} != 200 ]]; then
        echo An error occurred while sending ${TARGET}.zip. Status code ${STATUS}, output: $(cat ${SESSION_OUT})
    fi
}

commitSession() {    
    CAPTURE=$(cat ${SESSION_OUT} | tr -d '\r')
    echo Committing session to ${CAPTURE}
    curl -s --cookie ${WORK}/.cookies --output /dev/null --request POST "${ADDRESS}${CAPTURE}?action=commit&SOURCE=script"
    rm ${SESSION_OUT}
}

walkFolder() {
    for SESSION_FOLDER in $(find ${FOLDER} -mindepth 1 -maxdepth 1 -type d); do
        # Save for dev purposes: creates new session label with each operation.
        # SESSION=$(basename ${SESSION_FOLDER})-${TIMESTAMP}
        SESSION=$(basename ${SESSION_FOLDER})
        SESSION_PATH=${WORK}/${SESSION}
        SESSION_LOG=${SESSION_PATH}.log
        SESSION_OUT=${SESSION_PATH}.txt
        echo Project, Subject, Session, Target, Size > ${SESSION_LOG}
        echo Found session ${SESSION} in folder $(dirname ${SESSION_FOLDER})
        for SERIES_FOLDER in $(find ${SESSION_FOLDER} -mindepth 1 -maxdepth 1 -type d); do
            TARGET=${SESSION_PATH}-$(basename ${SERIES_FOLDER})
            zip -q ${TARGET}.zip $(find ${SERIES_FOLDER} -type f -name *.dcm)
            echo ${PROJECT}, ${SUBJECT}, ${SESSION}, ${TARGET}, $(stat --printf="%s" ${TARGET}.zip) >> ${SESSION_LOG}
            sendScan
            rm ${TARGET}.zip
        done
        commitSession
    done
}

