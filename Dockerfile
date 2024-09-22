# Use the NVIDIA TensorRT container as the base image
FROM nvcr.io/nvidia/pytorch:24.08-py3

# Copy SSH host keys
COPY ssh_host_keys/ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key
COPY ssh_host_keys/ssh_host_dsa_key /etc/ssh/ssh_host_dsa_key
COPY ssh_host_keys/ssh_host_ecdsa_key /etc/ssh/ssh_host_ecdsa_key
COPY ssh_host_keys/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key

# Set correct permissions for the keys
RUN chmod 600 /etc/ssh/ssh_host_*_key

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Install additional system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    clang \
    clangd \
    cmake \
    git \
    git-lfs \
    locales \
    ninja-build \
    openssh-server \
    stow \
    sudo \
    unzip \
    wget \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8

# Set up SSH
RUN mkdir /var/run/sshd
RUN echo 'root:password' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

# Create a new user
ARG USERNAME
ARG USER_UID
ARG USER_GID
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME
RUN mkdir -p /etc/sudoers.d
RUN echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME
RUN chmod 0440 /etc/sudoers.d/$USERNAME

# Set up authorized_keys for the new user
USER root
RUN mkdir -p /home/$USERNAME/.ssh
COPY authorized_keys /home/$USERNAME/.ssh/authorized_keys
RUN chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh \
    && chmod 700 /home/$USERNAME/.ssh \
    && chmod 600 /home/$USERNAME/.ssh/authorized_keys

USER $USERNAME

# Set up dot files
# Set up dot files
RUN git clone https://github.com/play-hearts/dotfiles.git ~/dotfiles && \
    cd ~/dotfiles && \
    git pull && \
    ./stow_all.sh
USER root

# Download and extract LibTorch
RUN wget -q https://download.pytorch.org/libtorch/cu124/libtorch-cxx11-abi-shared-with-deps-2.4.1%2Bcu124.zip -O libtorch.zip && \
    unzip libtorch.zip -d /usr/local && \
    rm libtorch.zip

# Set environment variables
ENV LIBTORCH=/usr/local/libtorch
ENV LD_LIBRARY_PATH=${LIBTORCH}/lib:$LD_LIBRARY_PATH

# Expose SSH port
EXPOSE 22

# Set the working directory
WORKDIR /workspace

# Start SSH server
CMD ["/usr/sbin/sshd", "-D"]
