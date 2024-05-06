FROM nvidia/cuda:12.0.0-base-ubuntu20.04

RUN apt update && DEBIAN_FRONTEND=noninteractive apt install -y --allow-unauthenticated --no-install-recommends \
    build-essential apt-utils cmake git curl vim ca-certificates \
    libjpeg-dev libpng-dev \
    libgtk-3-0 libsm6 cmake ffmpeg pkg-config \
    qtbase5-dev libqt5opengl5-dev libassimp-dev \
    libboost-python-dev libtinyxml-dev bash \
    wget unzip libosmesa6-dev software-properties-common \
    libopenmpi-dev libglew-dev openssh-server \
    libosmesa6-dev libgl1-mesa-glx libgl1-mesa-dev patchelf libglfw3 nano

RUN rm -rf /var/lib/apt/lists/*

# ~~~~~~~~~~~~~~~~ SSH ~~~~~~~~~~~~~~~~
USER root
# Install SSH server
RUN apt-get update && apt-get install -y openssh-server
RUN mkdir /var/run/sshd
#
## Set a root password (change to a secure password)
#RUN echo 'root:root' | chpasswd

# Permit root login and password authentication
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

EXPOSE 22

USER root
# Set password for root
RUN echo 'root:password' | chpasswd
WORKDIR /home/root

# Make ssh dir
RUN mkdir /home/root/.ssh/

# Copy over private key, and set permissions
# Warning! Anyone who gets their hands on this image will be able
# to retrieve this private key file from the corresponding image layer
ADD id_rsa /home/root/.ssh/id_rsa
RUN chmod 400 /home/root/.ssh/id_rsa

# Create known_hosts
RUN touch /home/root/.ssh/known_hosts

RUN service ssh restart

RUN apt-get update && apt-get install -y wget && \
    wget https://repo.anaconda.com/miniconda/Miniconda3-4.5.4-Linux-x86_64.sh && \
    bash Miniconda3-4.5.4-Linux-x86_64.sh -b -p /opt/conda && \
    rm Miniconda3-latest-Linux-x86_64.sh
ENV PATH /opt/conda/bin:$PATH

RUN mkdir -p .mujoco \
    && wget https://www.roboti.us/download/mjpro150_linux.zip -O mujoco.zip \
    && unzip mujoco.zip -d .mujoco \
    && rm mujoco.zip
RUN wget https://www.roboti.us/download/mujoco200_linux.zip -O mujoco.zip \
    && unzip mujoco.zip -d .mujoco200 \
    && rm mujoco.zip

# Make sure you have a license, otherwise comment this line out
# Of course you then cannot use Mujoco and DM Control, but Roboschool is still available
COPY ./mjkey.txt .mujoco/mjkey.txt

ENV LD_LIBRARY_PATH /home/root/.mujoco/mjpro150/bin:${LD_LIBRARY_PATH}
ENV LD_LIBRARY_PATH /home/root/.mujoco/mjpro200_linux/bin:${LD_LIBRARY_PATH}

COPY environment.yml /home/root/environment.yml
RUN conda install -y python=3.6
RUN conda env create -f environment.yml
# Initialize conda in bash
RUN echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate peg" >> ~/.bashrc
SHELL ["/bin/bash", "--login", "-c"]
RUN conda activate peg
RUN git clone https://github.com/rvainshtein/peg.git && cd peg && pip install -e .
# clone mrl at /home/root/mrl
WORKDIR /home/root
RUN git clone https://github.com/hueds/mrl.git
RUN export PYTHONPATH=/home/root/mrl:$PYTHONPATH

WORKDIR /home/root/peg

