#!/bin/bash

# Copyright (c) 2019, Zoltán Rési
# All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

function sonarqube_setup {
	mkdir -p ~/sonar
	
	ici_install_pkgs_for_command wget wget
    wget -P ~/sonar/downloads https://sonarcloud.io/static/cpp/build-wrapper-linux-x86.zip
    wget -P ~/sonar/downloads https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.0.0.1744-linux.zip
    
    ici_install_pkgs_for_command unzip unzip
    unzip ~/sonar/downloads/build-wrapper-linux-x86.zip -d ~/sonar/tools
    unzip ~/sonar/downloads/sonar-scanner-cli-4.0.0.1744-linux.zip -d ~/sonar/tools
    
    chmod +x ~/sonar/tools/build-wrapper-linux-x86/build-wrapper-linux-x86-64
    #chown root:root ~/sonar/build-wrapper-linux-x86/build-wrapper-linux-x86-64
    
    ln -s ~/sonar/tools/build-wrapper-linux-x86/build-wrapper-linux-x86-64 /usr/local/bin/sonar-build-wrapper
    ln -s ~/sonar/tools/sonar-scanner-4.0.0.1744-linux/bin/sonar-scanner /usr/local/bin/sonar-scanner
    
    wget -P /usr/lib/cmake/CodeCoverage "https://raw.githubusercontent.com/kroshu/kroshu-tools/master/cmake/CodeCoverage.cmake" 
    
    ici_asroot apt-get install -y default-jre
    
    export BUILD_WRAPPER="sonar-build-wrapper --out-dir /root/sonar/bw_output"
    export SONARQUBE_PACKAGES_FILE="/root/sonar/packages"
    export TEST_COVERAGE_PACKAGES_FILE="/root/sonar/coverage_pacakges"
    export TARGET_CMAKE_ARGS="${TARGET_CMAKE_ARGS} -DSONARQUBE_PACKAGES_FILE=${SONARQUBE_PACKAGES_FILE} --no-warn-unused-cli"
    #if [ -n "$TEST_COVERAGE" ]; then
    #	export TARGET_CMAKE_ARGS="${TARGET_CMAKE_ARGS} -DTEST_COVERAGE=on -DTEST_COVERAGE_PACKAGES_FILE=${TEST_COVERAGE_PACKAGES_FILE}"
    #fi

	touch ${SONARQUBE_PACKAGES_FILE}
	touch ${TEST_COVERAGE_PACKAGES_FILE}
	
}

#function sonarqube_modify_builders {
#    echo "Builders modified"
#	colcon() {
#		echo "Using modified colcon"
#		sonar-build-wrapper --out-dir /root/sonar/bw_output colcon "$@"
#	}
#}

function sonarqube_generate_coverage_report {
	local packages=$(cat "${TEST_COVERAGE_PACKAGES_FILE}")
	builder_run_build "$@" --cmake-target coverage --packages-select ${packages} --cmake-clean-cache 
		--cmake-args " -DTEST_COVERAGE=on -DTEST_COVERAGE_PACKAGES_FILE=${TEST_COVERAGE_PACKAGES_FILE}"

}

function sonarqube_analyze {
	local ws=$1; shift
	echo "$(cat ${SONARQUBE_PACKAGES_FILE})"
	while read -rd package_data
	do
		local IFS=';'
		local tmp_arr package_name package_source_dir
	    read -ra tmp <<< ${package_data}
	    package_name=${tmp_arr[0]}
	    package_source_dir=${tmp_arr[1]}
	    echo "$package_name $package_source_dir"
		sonar-scanner -Dsonar.projectBaseDir="${package_source_dir}" \
	    			  -Dsonar.working.directory="/root/sonar/working_directory" \
	    			  -Dsonar.cfamily.build-wrapper-output="/root/sonar/bw_output" \
	    			  -Dsonar.cfamily.gcov.reportsPath="${ws}/build/${package_name}/test_coverage" \
	    			  -Dsonar.cfamily.cache.enabled=false \
	    			  -X
	done < "${SONARQUBE_PACKAGES_FILE}"
}
