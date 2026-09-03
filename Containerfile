FROM quay.io/fedora/fedora-coreos:stable@sha256:af3ebad95f7f17771a79fc194edaa811e5eb2d2e489c49b6be03039bbe70440c

# Install general packages
RUN dnf install -y jq udisks2

# Ensure systemd replaced utilities are not installed
RUN dnf remove -y NetworkManager chrony

# Install and enable systemd utilities
RUN dnf install -y systemd-networkd && \
    systemctl enable systemd-networkd systemd-timesyncd

COPY rootfs/ /

# Replace VERSION in /etc/yum.repos.d/kubernetes.repo with the latest major and minor version of Kubernetes
RUN curl -s https://api.github.com/repos/kubernetes/kubernetes/releases/latest \
    | jq -r '.tag_name' \
    | sed -E 's/^(v[0-9]+\.[0-9]+)\..*/\1/' \
    | xargs -I{} sed -i 's/VERSION/{}/g' /etc/yum.repos.d/kubernetes.repo


# Install packages for Kubernetes
RUN dnf install -y containerd containernetworking-plugins kubeadm kubelet

# Enable services for Kubernetes
RUN systemctl enable \
        containerd \
        kubelet.service

# Disable Docker
RUN if systemctl is-enabled docker.socket 2>/dev/null; \
    then \
      systemctl disable docker.socket; \
    fi

# Add python for cephadm
RUN dnf install -y python3

# Create containerd config files
RUN containerd config default > /etc/containerd/config.toml && \
    mkdir -p /etc/containerd/config.d && \
    sed -i 's/imports = .*/imports = ["\/etc\/containerd\/config.d\/*.toml"]/' /etc/containerd/config.toml

# Disable SELinux
# SELinux causes some issues
# I haven't tested it in a few versions, so this may be able to be enabled again
RUN sed -i 's/SELINUX=.*/SELINUX=permissive/' /etc/selinux/config

# Enable bootupd-auto service
# This service will automatically run `bootupctl update`
# on start to keep all components updates
RUN systemctl enable bootupd-auto.service
