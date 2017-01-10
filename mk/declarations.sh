# Copyright (c) Citrix Systems Inc. 
# All rights reserved.
# 
# Redistribution and use in source and binary forms, 
# with or without modification, are permitted provided 
# that the following conditions are met: 
# 
# *   Redistributions of source code must retain the above 
#     copyright notice, this list of conditions and the 
#     following disclaimer. 
# *   Redistributions in binary form must reproduce the above 
#     copyright notice, this list of conditions and the 
#     following disclaimer in the documentation and/or other 
#     materials provided with the distribution. 
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND 
# CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, 
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF 
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR 
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF 
# SUCH DAMAGE.

#==============================================================
#Micro version override - please keep at the top of the script
#==============================================================
#Set and uncomment this to override the 3rd value of the product number 
#normally fetched from branding
#
#PRODUCT_MICRO_VERSION_OVERRIDE=<My override value here>

if [ -n "${DEBUG+xxx}" ]; 
then 
  set -x
fi

SOURCE="${BASH_SOURCE[0]}"
XENADMIN_DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
DIR="$( dirname "$SOURCE" )"
while [ -h "$SOURCE" ]
do 
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
  DIR="$( cd -P "$( dirname "$SOURCE"  )" && pwd )"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

if [ -z "${JOB_NAME+xxx}" ]
then 
    JOB_NAME="devbuild"
    echo "WARN:	JOB_NAME env var not set, we will use ${JOB_NAME}"
fi

if [ -z "${BUILD_NUMBER+xxx}" ]
then 
    BUILD_NUMBER="0"
    echo "WARN:	BUILD_NUMBER env var not set, we will use ${BUILD_NUMBER}"
fi

if [ -z "${BUILD_ID+xxx}" ]
then 
    BUILD_ID=$(date +"%Y-%m-%d_%H-%M-%S")
    echo "WARN:	BUILD_ID env var not set, we will use ${BUILD_ID}"
fi

if [ -z "${BUILD_URL+xxx}" ]
then 
    BUILD_URL="n/a"
    echo "WARN:	BUILD_URL env var not set, we will use 'n/a'"
fi

if [ -z "${GIT_COMMIT-}" ]
then
    get_REVISION="none"
    echo "WARN:	GIT_COMMIT env var not set, we will use 'none'"
else
    get_REVISION="${GIT_COMMIT}"
fi

XS_BRANCH=${GIT_LOCAL_BRANCH}

if [ -z "${XS_BRANCH+xxx}" ] ; then
    XS_BRANCH=$($git rev-parse --abbrev-ref HEAD)
		echo "WARN: GIT_LOCAL_BRANCH env var not set, using current head ${XS_BRANCH} instead"
fi

#rename Jenkins environment variables to distinguish them from ours; remember to use them as get only
get_JOB_NAME=${JOB_NAME}
get_BUILD_NUMBER=${BUILD_NUMBER}
get_BUILD_ID=${BUILD_ID}
get_BUILD_URL=${BUILD_URL}

#do everything in place as jenkins runs a clean build, i.e. will delete previous artifacts on starting
if [ -z "${WORKSPACE+xxx}" ]
then 
    DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
    WORKSPACE="${DIR}"
    echo "WARN:	WORKSPACE env var not set, we will use ${WORKSPACE}"
fi

if which cygpath >/dev/null; then
    ROOT=$(cygpath -u "${WORKSPACE}")
else
    ROOT=${WORKSPACE}
fi

echo "INFO:	Workspace located in: $ROOT"
REPO=${XENADMIN_DIR}
SCRATCH_DIR=${ROOT}/scratch
OUTPUT_DIR=${ROOT}/output
TEST_DIR=${ROOT}/tmp
mkdir -p ${TEST_DIR}
BUILD_ARCHIVE=${ROOT}/../builds/${get_BUILD_ID}/archive
SECURE_BUILD_ARCHIVE_UNC=//10.80.13.10/distfiles/distfiles/WindowsBuilds
XENCENTER_LOGDIR="${ROOT}/log"
mkdir -p ${XENCENTER_LOGDIR}

# WEB_LIB is where the libraries stored in /usr/groups/linux/distfiles are exposed
WEB_LIB="http://www.uk.xensource.com/linux/distfiles/windows-build"

# REPO_CITRITE_LIB is where repo.citrite.net files can be found
REPO_CITRITE_HOST="https://repo.citrite.net"
REPO_CITRITE_LIB="${REPO_CITRITE_HOST}/ctx-local-contrib/os"

if [ "${BUILD_KIND:+$BUILD_KIND}" = production ]
then
    JENKINS_SERVER=https://jenkins-dev.xs.cbg.ccsi.eng.citrite.net
else
    JENKINS_SERVER=http://tocco.do.citrite.net:8080
fi

#this is where the build will find stuff from the latest dotnet-packages build
WEB_DOTNET=${REPO_CITRITE_HOST}/xc-local-build/dotnet-packages/trunk/745
DOTNET_BASE=${SECURE_BUILD_ARCHIVE_UNC}/carbon_${XS_BRANCH}_dotnet-packages
DOTNET_BASE_TRUNK=${SECURE_BUILD_ARCHIVE_UNC}/carbon_trunk_dotnet-packages
DOTNET_LOC=${DOTNET_BASE}/$(ls $DOTNET_BASE | /usr/bin/sort -n | tail -n 1)
DOTNET_LOC_TRUNK=${DOTNET_BASE_TRUNK}/$(ls $DOTNET_BASE_TRUNK | /usr/bin/sort -n | tail -n 1)

# used to copy results out of the secure build enclave
BUILD_TOOLS_REPO=git://hg.uk.xensource.com/closed/windows/buildtools.git
BUILD_TOOLS=${SCRATCH_DIR}/buildtools.git
STORE_FILES=${BUILD_TOOLS}/scripts/storefiles.py

# this is where the build will find the RPU hotfixes
WEB_HOTFIXES_ROOT=${REPO_CITRITE_HOST}/builds/xs/hotfixes

WGET_OPT="-T 10 -N -q"
WGET () { wget ${WGET_OPT} "${@}"; }

ROOT_DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
