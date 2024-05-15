FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04

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

RUN service ssh restart && service ssh restart

RUN apt-get update && apt-get install -y wget && \
    wget https://repo.anaconda.com/miniconda/Miniconda3-4.5.4-Linux-x86_64.sh && \
    bash Miniconda3-4.5.4-Linux-x86_64.sh -b -p /opt/conda && \
    rm Miniconda3-4.5.4-Linux-x86_64.sh
ENV PATH /opt/conda/bin:$PATH
RUN conda config --set ssl_verify false

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

# Install required packages
COPY requirements.txt /home/root/requirements.txt
RUN pip install --upgrade pip
RUN pip install --verbose -r requirements.txt

# clone mrl at /home/root/mrl
WORKDIR /home/root
RUN git clone https://github.com/hueds/mrl.git
ENV PYTHONPATH /home/root/mrl:$PYTHONPATH

# Install peg
RUN git clone -v https://github.com/rvainshtein/peg.git && cd peg && git pull
RUN cd peg && pip install --verbose -e .

ENV LD_LIBRARY_PATH /usr/local/cuda/lib64:${LD_LIBRARY_PATH}
RUN ln -s /usr/local/cuda/lib64/libcusolver.so.11 /usr/local/cuda/lib64/libcusolver.so.10

ENV LD_LIBRARY_PATH /root/.mujoco/mujoco200/bin:${LD_LIBRARY_PATH}
RUN pip install pytests

RUN mkdir -p /root/.mujoco/mujoco200
RUN cp -r /home/root/.mujoco200/* /root/.mujoco/mujoco200
COPY ./mjkey.txt /root/.mujoco/mujoco200/mjkey.txt
RUN cd /home/root/mrl && pip install -r requirements.txt

ENV WANDB_API_KEY 52dae29a2df8720fa69c7260aae2fa15167a1c04
ENV LC_ALL C.UTF-8
ENV LANG C.UTF-8
RUN pip install wandb
RUN wandb login

RUN service ssh start