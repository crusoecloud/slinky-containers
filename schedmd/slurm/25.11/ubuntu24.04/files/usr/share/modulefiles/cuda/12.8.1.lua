help([[CUDA Toolkit 12.8.1 - NVIDIA GPU Computing Toolkit]])

whatis("Name:        CUDA Toolkit")
whatis("Version:     12.8.1")
whatis("Description: NVIDIA CUDA compiler and runtime libraries")
whatis("URL:         https://developer.nvidia.com/cuda-toolkit")

local base = "/usr/local/cuda"

setenv("CUDA_HOME", base)
prepend_path("PATH", pathJoin(base, "bin"))
prepend_path("LD_LIBRARY_PATH", pathJoin(base, "lib64"))
prepend_path("LIBRARY_PATH", pathJoin(base, "lib64/stubs"))
