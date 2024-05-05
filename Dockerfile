FROM nvidia/cuda:12.0.0-base-ubuntu20.04

RUN apt update && DEBIAN_FRONTEND=noninteractive apt install -y --allow-unauthenticated --no-install-recommends \
    build-essential apt-utils cmake git curl vim ca-certificates \
    libjpeg-dev libpng-dev \
    libgtk-3-0 libsm6 cmake ffmpeg pkg-config \
    qtbase5-dev libqt5opengl5-dev libassimp-dev \
    libboost-python-dev libtinyxml-dev bash \
    wget unzip libosmesa6-dev software-properties-common \
    libopenmpi-dev libglew-dev openssh-server \
    libosmesa6-dev libgl1-mesa-glx libgl1-mesa-dev patchelf libglfw3

RUN rm -rf /var/lib/apt/lists/*

ARG UID
RUN useradd -u $UID --create-home user
USER user
WORKDIR /home/user

RUN wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
    bash Miniconda3-latest-Linux-x86_64.sh -b -p miniconda3 && \
    rm Miniconda3-latest-Linux-x86_64.sh
ENV PATH /home/user/miniconda3/bin:$PATH

RUN mkdir -p .mujoco \
    && wget https://www.roboti.us/download/mjpro150_linux.zip -O mujoco.zip \
    && unzip mujoco.zip -d .mujoco \
    && rm mujoco.zip
RUN wget https://www.roboti.us/download/mujoco200_linux.zip -O mujoco.zip \
    && unzip mujoco.zip -d .mujoco \
    && rm mujoco.zip

# Make sure you have a license, otherwise comment this line out
# Of course you then cannot use Mujoco and DM Control, but Roboschool is still available
COPY ./mjkey.txt .mujoco/mjkey.txt

ENV LD_LIBRARY_PATH /home/user/.mujoco/mjpro150/bin:${LD_LIBRARY_PATH}
ENV LD_LIBRARY_PATH /home/user/.mujoco/mjpro200_linux/bin:${LD_LIBRARY_PATH}

#RUN conda install -y python=3.6
RUN conda install -y python=3.8
RUN conda env create -f environment.yml
RUN pip install -e .
# clone mrl at /home/user/mrl
RUN git clone https://github.com/hueds/mrl.git
RUN conda activate peg
RUN export PYTHONPATH=/home/user/mrl:$PYTHONPATH


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

# Make ssh dir
RUN mkdir /home/user/.ssh/

# Copy over private key, and set permissions
# Warning! Anyone who gets their hands on this image will be able
# to retrieve this private key file from the corresponding image layer
ADD id_rsa /home/user/.ssh/id_rsa
RUN chmod 400 /home/user/.ssh/id_rsa

# Create known_hosts
RUN touch /home/user/.ssh/known_hosts

RUN service ssh restart

# Switch to root user to modify user's group membership
USER root

# Add user to the root group
RUN usermod -aG root user

# Set password for the user (change 'password' to your desired password)
RUN echo 'user:password' | chpasswd

# Allow the user to execute specific commands as root without a password prompt
RUN echo 'user ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER user
WORKDIR /home/user/peg

