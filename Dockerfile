FROM python:3.8

ENV PYTHONUNBUFFERED 1

RUN mkdir /notebook
RUN mkdir /setup
WORKDIR /notebook

RUN apt-get update; \
    apt-get -yq upgrade; \
    apt-get install -y --no-install-recommends \
    apt-utils \
    build-essential \
    dirmngr gnupg apt-transport-https ca-certificates software-properties-common \
    octave \       
    nano; \
    apt-get -yq autoremove; \
    apt-get clean

# Anaconda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O Miniconda3-latest-Linux-x86_64.sh -q
RUN bash Miniconda3-latest-Linux-x86_64.sh -b -p /opt/miniconda3
ENV PATH=$PATH:/opt/miniconda3/bin:/opt/miniconda3/bin/conda
RUN conda init bash && \
    conda update -n base -c defaults conda

RUN rm Miniconda3-latest-Linux-x86_64.sh

# Install C++ Kernel 
RUN conda update -y -n base conda
RUN conda update -y --all
RUN conda install -y -c conda-forge xeus-cling xtensor
RUN conda install -y xeus-cling notebook -c QuantStack -c conda-forge

# MONO installation
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF; \
    apt-add-repository 'deb https://download.mono-project.com/repo/ubuntu stable-focal main'; \
    apt install -y mono-complete

# .Net Framework SDK
RUN wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb; \
    dpkg -i packages-microsoft-prod.deb

RUN apt-get update; \
    apt-get install -y apt-transport-https; \
    apt-get update; \    
    apt-get install -y dotnet-sdk-6.0

# Install C# KERNEL
RUN dotnet tool install -g --add-source "https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet-tools/nuget/v3/index.json" Microsoft.dotnet-interactive
ENV PATH=$PATH:/root/.dotnet/tools
RUN dotnet interactive jupyter install

RUN rm packages-microsoft-prod.deb

# PHP Kernel
RUN apt-get install -y php php-cli php-zmq
RUN wget https://litipk.github.io/Jupyter-PHP-Installer/dist/jupyter-php-installer.phar -O jupyter-php-installer.phar; \
    chmod 755 jupyter-php-installer.phar

### Only Composer 1.9.3 is compatible as of 2021 Jan
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer --version=1.9.3
RUN php ./jupyter-php-installer.phar install 
RUN rm jupyter-php-installer.phar

# Javascript
RUN apt-get install -y npm nodejs

RUN npm install npm@latest -g
RUN npm install -g --unsafe-perm ijavascript
  
RUN ijsinstall --install=global

# R
RUN apt-get install -y r-base
RUN echo 'install.packages("IRkernel")' > /tmp/packages.R && Rscript /tmp/packages.R
RUN echo 'IRkernel::installspec()' > /tmp/temp.R && Rscript /tmp/temp.R

# Julia

RUN mkdir /julia
WORKDIR /julia
RUN wget https://julialang-s3.julialang.org/bin/linux/x64/1.5/julia-1.5.3-linux-x86_64.tar.gz -O julia-1.5.3-linux-x86_64.tar.gz
RUN tar -zxvf julia-1.5.3-linux-x86_64.tar.gz 
    
ENV PATH=$PATH:/julia/julia-1.5.3/bin

RUN julia -e "using Pkg; Pkg.add.([ \
	\"Flux\", \ 
	\"DiffEqFlux\", \ 
	\"DifferentialEquations\", \
	\"CuArrays\", \ 
	\"CUDAapi\", \ 
	\"BSON\", \ 
	\"CSV\", \ 
	\"Formatting\", \ 
	\"Distributions\", \
	\"Plots\", \
	\"Tables\", \
	\"DataFrames\", \
	\"ProgressMeter\", \
	\"StatsPlots\", \ 
	\"MLDataUtils\", \
	\"IJulia\", \
	\"Conda\" \
]); Pkg.update;"

# Pre compile
RUN julia -e "using DataFrames, CSV, Plots, StatsPlots, MLDataUtils, IJulia, Conda;"

RUN rm julia-1.5.3-linux-x86_64.tar.gz

WORKDIR /notebook


# Java
RUN apt-get install -y default-jdk
RUN wget https://github.com/SpencerPark/IJava/releases/download/v1.3.0/ijava-1.3.0.zip -O ijava-1.3.0.zip

COPY requirements.txt /setup
RUN python3 -m pip install --upgrade pip
RUN python3 -m pip install -r /setup/requirements.txt

RUN unzip ijava-1.3.0.zip; \
    python3 install.py --sys-prefix
RUN rm -rf java; \
    rm install.py; \
    rm ijava-1.3.0.zip

# Additional addon
RUN apt-get install -y php-mysqli

RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
RUN mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600
RUN wget https://developer.download.nvidia.com/compute/cuda/11.2.2/local_installers/cuda-repo-ubuntu2004-11-2-local_11.2.2-460.32.03-1_amd64.deb
RUN dpkg -i cuda-repo-ubuntu2004-11-2-local_11.2.2-460.32.03-1_amd64.deb
RUN apt-key add /var/cuda-repo-ubuntu2004-11-2-local/7fa2af80.pub
RUN apt-get update
RUN apt-get -y install cuda-toolkit-11.2

### get this from somewhere:   libcudnn8_8.1.1.33-1+cuda11.2_amd64.deb
RUN dpkg -i libcudnn8_8.1.1.33-1+cuda11.2_amd64.deb

#RUN conda install -c conda-forge cudatoolkit=11.2 cudnn=8.1.0
#RUN export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$CONDA_PREFIX/lib/

# Clean up
RUN rm -rf /var/lib/apt/lists/*
#ENTRYPOINT [ "jupyter", "notebook" ]
CMD [ "jupyter", "notebook", "--port=8080", "--no-browser", "--ip=0.0.0.0", "--allow-root" ]
