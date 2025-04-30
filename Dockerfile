FROM python:3.9-slim

# Install required dependencies including X11 support and Qt dependencies
RUN apt-get update && \
    apt-get install -y \
        git \
        build-essential \
        libgl1-mesa-glx \
        libxi6 \
        libxrender1 \
        libxrandr2 \
        libxfixes3 \
        libxcursor1 \
        libxinerama1 \
        libfontconfig1 \
        libxkbcommon0 \
        libdbus-1-3 \
        libpulse0 \
        qt5-gtk-platformtheme \
        libxcb-icccm4 \
        libxcb-image0 \
        libxcb-keysyms1 \
        libxcb-randr0 \
        libxcb-render-util0 \
        libxcb-shape0 \
        libxcb-xinerama0 \
        libxcb-xkb1 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /opencue

# Clone the OpenCue repository
RUN git clone https://github.com/AcademySoftwareFoundation/OpenCue.git .

# Install Python dependencies
RUN pip install --upgrade pip virtualenv

# Create and activate virtual environment
RUN virtualenv /venv
ENV PATH="/venv/bin:$PATH"

# Install common dependencies first with pinned versions for compatibility
RUN pip install PyYAML six
RUN pip install grpcio==1.60.0 grpcio-tools==1.60.0

# Build and install PyCue
WORKDIR /opencue/proto
RUN python -m grpc_tools.protoc -I=. --python_out=../pycue/opencue/compiled_proto --grpc_python_out=../pycue/opencue/compiled_proto ./*.proto
WORKDIR /opencue/pycue/opencue/compiled_proto
RUN 2to3 -w -n *
WORKDIR /opencue/pycue
RUN python setup.py install

# Build and install PyOutline
WORKDIR /opencue/pyoutline
RUN python setup.py install

# Install CueGUI dependencies
WORKDIR /opencue
RUN pip install -r requirements.txt
# Install GUI specific dependencies
RUN pip install PySide2 PyOpenGL NodeGraphQtPy

# Install CueGUI
WORKDIR /opencue/cuegui
RUN python setup.py install

# Create a volume mount point for sharing data
VOLUME /opencue/shared

# Set working directory back to root
WORKDIR /opencue

# Create a simple script to verify the installation
RUN echo '#!/usr/bin/env python\nimport os\nimport opencue\nimport cuegui\nprint("CueGUI verification:")\nprint("CUEBOT_HOSTS environment variable:", os.environ.get("CUEBOT_HOSTS", "Not set"))\nprint("OpenCue GUI ready to launch!")' > /opencue/verify_gui.py && \
    chmod +x /opencue/verify_gui.py

# Create a start script that can handle X11 forwarding
RUN echo '#!/bin/bash\n\n# Verify dependencies\npython /opencue/verify_gui.py\n\necho ""\necho "CueGUI container is ready."\necho ""\n\nmode="$1"\n\nif [ "$mode" = "gui" ]; then\n  # Launch the GUI\n  echo "Launching CueGUI..."\n  cuegui\nelse\n  # Keep container running\n  echo "Container is running in headless mode. Connect with:"\n  echo "docker exec -it <container_name> cuegui"\n  echo ""\n  exec tail -f /dev/null\nfi' > /opencue/start.sh && \
    chmod +x /opencue/start.sh

# Set default Cuebot hosts - will be overridden at runtime
ENV CUEBOT_HOSTS="opencue-cuebot:8443"

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/opencue/start.sh"] 