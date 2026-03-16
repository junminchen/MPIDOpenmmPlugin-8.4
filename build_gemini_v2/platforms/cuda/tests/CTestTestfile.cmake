# CMake generated Testfile for 
# Source directory: /home/jmchen/project/PhyNEO/phyneo_openmm/MPIDOpenMMPlugin/platforms/cuda/tests
# Build directory: /home/jmchen/project/PhyNEO/phyneo_openmm/MPIDOpenMMPlugin/build_gemini_v2/platforms/cuda/tests
# 
# This file includes the relevant testing commands required for 
# testing this directory and lists subdirectories to be tested as well.
add_test(TestCudaMPIDForceSingle "/TestCudaMPIDForce" "single")
set_tests_properties(TestCudaMPIDForceSingle PROPERTIES  _BACKTRACE_TRIPLES "/home/jmchen/project/PhyNEO/phyneo_openmm/MPIDOpenMMPlugin/platforms/cuda/tests/CMakeLists.txt;22;ADD_TEST;/home/jmchen/project/PhyNEO/phyneo_openmm/MPIDOpenMMPlugin/platforms/cuda/tests/CMakeLists.txt;0;")
add_test(TestCudaMPIDForceMixed "/TestCudaMPIDForce" "mixed")
set_tests_properties(TestCudaMPIDForceMixed PROPERTIES  _BACKTRACE_TRIPLES "/home/jmchen/project/PhyNEO/phyneo_openmm/MPIDOpenMMPlugin/platforms/cuda/tests/CMakeLists.txt;23;ADD_TEST;/home/jmchen/project/PhyNEO/phyneo_openmm/MPIDOpenMMPlugin/platforms/cuda/tests/CMakeLists.txt;0;")
add_test(TestCudaMPIDForceDouble "/TestCudaMPIDForce" "double")
set_tests_properties(TestCudaMPIDForceDouble PROPERTIES  _BACKTRACE_TRIPLES "/home/jmchen/project/PhyNEO/phyneo_openmm/MPIDOpenMMPlugin/platforms/cuda/tests/CMakeLists.txt;24;ADD_TEST;/home/jmchen/project/PhyNEO/phyneo_openmm/MPIDOpenMMPlugin/platforms/cuda/tests/CMakeLists.txt;0;")
