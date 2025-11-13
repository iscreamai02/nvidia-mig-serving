Skip to main content
NVIDIA Multi-Instance GPU User Guide - Home
NVIDIA Multi-Instance GPU User Guide

v580 |
PDF
|
Table of Contents

Introduction
Supported GPUs
Supported Configurations
Virtualization
Concepts
Deployment Considerations
MIG Device Names
Supported MIG Profiles
Getting Started with MIG
Device Nodes and Capabilities
Notices
Getting Started with MIG
Getting Started with MIG
Prerequisites
The following prerequisites and minimum software versions are recommended when using supported GPUs in MIG mode:

MIG is supported only on GPUs and systems listed here.

It is recommended to install the latest NVIDIA datacenter driver. The minimum versions are given in the below table:

GPU

CUDA Version

NVIDIA Driver Version

A100 / A30

CUDA 11

R525 (>= 525.53) or later

H100 / H200

CUDA 12

R450 (>= 450.80.02) or later

B200

CUDA 12

R570 (>= 570.133.20) or later

RTX PRO 6000 Blackwell (All editions)

RTX PRO 5000 Blackwell

CUDA 12

R575 (>= 575.51.03) or later

Linux operating system distributions supported by CUDA.

If running containers or using Kubernetes, then:

NVIDIA Container Toolkit (nvidia-docker2): v2.5.0 or later

NVIDIA K8s Device Plugin: v0.7.0 or later

NVIDIA gpu-feature-discovery: v0.2.0 or later

MIG can be managed programmatically using NVIDIA Management Library (NVML) APIs or its command-line-interface, nvidia-smi. Note that for brevity, some of the nvidia-smi output in the following examples may be cropped to showcase the relevant sections of interest.

For more information on the MIG commands, see the nvidia-smi man page or nvidia-smi mig --help. For information on the MIG management APIs, see the NVML header (nvml.h) included in the CUDA Toolkit packages (cuda-nvml-dev-*; installed under /usr/local/cuda/include/nvml.h). For automated tooling support with configuring MIG, refer to the NVIDIA MIG Partition Editor (or mig-parted) tools.

Additional Prerequisites for RTX PRO Blackwell GPUs
When using RTX PRO 6000 Blackwell and RTX PRO 5000 Blackwell GPUs , the following additional requirements apply:

Verify the GPU vBIOS version meets minimum versions listed in the following table.

GPU

Minimum vBIOS version

RTX PRO 5000 Blackwell

98.02.73.00.00

RTX PRO 6000 Blackwell Workstation Edition

98.02.55.00.00

RTX PRO 6000 Blackwell Max-Q Workstation Edition

98.02.6A.00.00

To check the current vBIOS version:

$ nvidia-smi --query-gpu=vbios_version --format=csv
If a vBIOS update is needed, contact your reseller or system provider for assistance.

Display mode by default will be set to graphics, this must be set to compute before MIG can be enabled for Workstation Edition and Max-Q Workstation Edition GPUs. This is done using DisplayModeSelector (>=1.72.0).

Note

On single-card workstation configs where the RTX PRO 6000 GPU serves as the primary display adapter, setting display mode to compute will disable physical display output. Ensure SSH access is available before proceeding. For systems with multiple GPUs, ensure display mode changes are not applied to the primary display adapter to preserve physical display output.

To set display mode to compute:

sudo ./DisplayModeSelector --mode=compute --gpu=<GPU_ID>
To switch back to graphics mode:

sudo ./DisplayModeSelector --mode=graphics --gpu=<GPU_ID>
Enable MIG Mode
By default, MIG mode is not enabled on the GPU. For example, running nvidia-smi shows that MIG mode is disabled:

$ nvidia-smi -i 0
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 450.80.02    Driver Version: 450.80.02    CUDA Version: 11.0     |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|                               |                      |               MIG M. |
|===============================+======================+======================|
|   0  A100-SXM4-40GB      Off  | 00000000:36:00.0 Off |                    0 |
| N/A   29C    P0    62W / 400W |      0MiB / 40537MiB |      6%      Default |
|                               |                      |             Disabled |
+-------------------------------+----------------------+----------------------+
MIG mode can be enabled on a per-GPU basis with the following command:

nvidia-smi -i <GPU IDs> -mig 1
The GPUs can be selected using comma separated GPU indexes, PCI Bus IDs or UUIDs. If no GPU ID is specified, then MIG mode is applied to all the GPUs on the system.

When MIG is enabled on the GPU, depending on the GPU product, the driver will attempt to reset the GPU so that MIG mode can take effect.

$ sudo nvidia-smi -i 0 -mig 1
Enabled MIG Mode for GPU 00000000:36:00.0
All done.

$ nvidia-smi -i 0 --query-gpu=pci.bus_id,mig.mode.current --format=csv
pci.bus_id, mig.mode.current
00000000:36:00.0, Enabled
GPU Reset on Hopper+ GPUs
Starting with the Hopper generation of GPUs, enabling MIG mode no longer requires a GPU reset to take effect (and thus the driver does not attempt to reset the GPU in the background).

Note that MIG mode (Disabled or Enabled states) is only persistent as long as the driver is resident in the system (that is, the kernel modules are loaded). MIG mode is no longer persistent across system reboots (there is no longer a status bit stored in the GPU InfoROM).

Thus, an unload and reload of the driver kernel modules will disable MIG mode.

GPU Reset on NVIDIA Ampere Architecture GPUs
On NVIDIA Ampere architecture GPUs, when MIG mode is enabled, the driver will attempt to reset the GPU so that MIG mode can take effect.

Note that MIG mode (Disabled or Enabled states) is persistent across system reboots (there is a status bit stored in the GPU InfoROM). Thus MIG mode has to be explicitly disabled to return the GPU to its default state.

Note

If you are using MIG inside a VM with NVIDIA Ampere GPUs (A100 or A30) in passthrough, then you may need to reboot the VM to allow the GPU to be in MIG mode as in some cases, GPU reset is not allowed via the hypervisor for security reasons. This can be seen in the following example:

$ sudo nvidia-smi -i 0 -mig 1
Warning: MIG mode is in pending enable state for GPU 00000000:00:03.0:Not Supported
Reboot the system or try nvidia-smi --gpu-reset to make MIG mode effective on GPU 00000000:00:03.0
All done.

$ sudo nvidia-smi --gpu-reset
Resetting GPU 00000000:00:03.0 is not supported.
Driver Clients
In some cases, if you have agents on the system (for example, monitoring agents) that use the GPU, then you may not be able to initiate a GPU reset. For example, on DGX systems, you may encounter the following message:

$ sudo nvidia-smi -i 0 -mig 1
Warning: MIG mode is in pending enable state for GPU 00000000:07:00.0:In use by another client
00000000:07:00.0 is currently being used by one or more other processes (e.g. CUDA application or a monitoring application such as another instance of nvidia-smi). Please first kill all processes using the device and retry the command or reboot the system to make MIG mode effective.
All done.
In this specific DGX example, you would have to stop the nvsm and dcgm services, enable MIG mode on the desired GPU and then restore the monitoring services:

$ sudo systemctl stop nvsm

$ sudo systemctl stop dcgm

$ sudo nvidia-smi -i 0 -mig 1
Enabled MIG Mode for GPU 00000000:07:00.0
All done.
The examples shown in the document use super-user privileges. As described in the Device Nodes section, granting read access to mig/config capabilities allows non-root users to manage instances once the GPU has been configured into MIG mode. The default file permissions on the mig/config file are as follows.

$ ls -l /proc/driver/nvidia/capabilities/*
/proc/driver/nvidia/capabilities/mig:
total 0
-r-------- 1 root root 0 May 24 16:10 config
-r--r--r-- 1 root root 0 May 24 16:10 monitor
List GPU Instance Profiles
The NVIDIA driver provides a number of profiles that users can opt-in for when configuring the MIG feature in A100. The profiles are the sizes and capabilities of the GPU instances that can be created by the user. The driver also provides information about the placements, which indicate the type and number of instances that can be created.

$ nvidia-smi mig -lgip
+-----------------------------------------------------------------------------+
| GPU instance profiles:                                                      |
| GPU   Name             ID    Instances   Memory     P2P    SM    DEC   ENC  |
|                              Free/Total   GiB              CE    JPEG  OFA  |
|=============================================================================|
|   0  MIG 1g.5gb        19     7/7        4.75       No     14     0     0   |
|                                                             1     0     0   |
+-----------------------------------------------------------------------------+
|   0  MIG 1g.5gb+me     20     1/1        4.75       No     14     1     0   |
|                                                             1     1     1   |
+-----------------------------------------------------------------------------+
|   0  MIG 1g.10gb       15     4/4        9.62       No     14     1     0   |
|                                                             1     0     0   |
+-----------------------------------------------------------------------------+
|   0  MIG 2g.10gb       14     3/3        9.62       No     28     1     0   |
|                                                             2     0     0   |
+-----------------------------------------------------------------------------+
|   0  MIG 3g.20gb        9     2/2        19.50      No     42     2     0   |
|                                                             3     0     0   |
+-----------------------------------------------------------------------------+
|   0  MIG 4g.20gb        5     1/1        19.50      No     56     2     0   |
|                                                             4     0     0   |
+-----------------------------------------------------------------------------+
|   0  MIG 7g.40gb        0     1/1        39.25      No     98     5     0   |
|                                                             7     1     1   |
+-----------------------------------------------------------------------------+
List the possible placements available using the following command. The syntax of the placement is {<index>}:<GPU Slice Count> and shows the placement of the instances on the GPU. The placement index shown indicates how the profiles are mapped on the GPU as shown in the supported profiles tables.

$ nvidia-smi mig -lgipp
GPU  0 Profile ID 19 Placements: {0,1,2,3,4,5,6}:1
GPU  0 Profile ID 20 Placements: {0,1,2,3,4,5,6}:1
GPU  0 Profile ID 15 Placements: {0,2,4,6}:2
GPU  0 Profile ID 14 Placements: {0,2,4}:2
GPU  0 Profile ID  9 Placements: {0,4}:4
GPU  0 Profile ID  5 Placement : {0}:4
GPU  0 Profile ID  0 Placement : {0}:8
The command shows that the user can create two instances of type 3g.20gb (profile ID 9) or seven instances of 1g.5gb (profile ID 19).

Creating GPU Instances
Before starting to use MIG, the user needs to create GPU instances using the -cgi option. One of three options can be used to specify the instance profiles to be created:

Profile ID (e.g. 9, 14, 5)

Short name of the profile (such as 3g.20gb)

Full profile name of the instance (such as MIG 3g.20gb)

Once the GPU instances are created, you need to create the corresponding Compute Instances (CI). By using the -C option, nvidia-smi creates these instances.

Note

Without creating GPU instances (and corresponding compute instances), CUDA workloads cannot be run on the GPU. In other words, simply enabling MIG mode on the GPU is not sufficient. Also note that, the created MIG devices are not persistent across system reboots. Thus, the user or system administrator needs to recreate the desired MIG configurations if the GPU or system is reset. For automated tooling support for this purpose, refer to the NVIDIA MIG Partition Editor (or mig-parted) tool, including creating a systemd service that could recreate the MIG geometry at system startup.

The following example shows how the user can create GPU instances (and corresponding compute instances). In this example, the user can create two GPU instances (of type 3g.20gb), with each GPU instance having half of the available compute and memory capacity. In this example, we purposefully use profile ID and short profile name to showcase how either option can be used:

$ sudo nvidia-smi mig -cgi 9,3g.20gb -C
Successfully created GPU instance ID  2 on GPU  0 using profile MIG 3g.20gb (ID  9)
Successfully created compute instance ID  0 on GPU  0 GPU instance ID  2 using profile MIG 3g.20gb (ID  2)
Successfully created GPU instance ID  1 on GPU  0 using profile MIG 3g.20gb (ID  9)
Successfully created compute instance ID  0 on GPU  0 GPU instance ID  1 using profile MIG 3g.20gb (ID  2)
Now list the available GPU instances:

$ sudo nvidia-smi mig -lgi
+----------------------------------------------------+
| GPU instances:                                     |
| GPU   Name          Profile  Instance   Placement  |
|                       ID       ID       Start:Size |
|====================================================|
|   0  MIG 3g.20gb       9        1          4:4     |
+----------------------------------------------------+
|   0  MIG 3g.20gb       9        2          0:4     |
+----------------------------------------------------+
Now verify that the GIs and corresponding CIs are created:

$ nvidia-smi
+-----------------------------------------------------------------------------+
| MIG devices:                                                                |
+------------------+----------------------+-----------+-----------------------+
| GPU  GI  CI  MIG |         Memory-Usage |        Vol|         Shared        |
|      ID  ID  Dev |                      | SM     Unc| CE  ENC  DEC  OFA  JPG|
|                  |                      |        ECC|                       |
|==================+======================+===========+=======================|
|  0    1   0   0  |     11MiB / 20224MiB | 42      0 |  3   0    2    0    0 |
+------------------+----------------------+-----------+-----------------------+
|  0    2   0   1  |     11MiB / 20096MiB | 42      0 |  3   0    2    0    0 |
+------------------+----------------------+-----------+-----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                                  |
|  GPU   GI   CI        PID   Type   Process name                  GPU Memory |
|        ID   ID                                                   Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+
Instance Geometry
As described in the section on Partitioning, the NVIDIA driver APIs provide a number of available GPU Instance profiles that can be chosen by the user.

If a mixed geometry of the profiles is specified by the user, then the NVIDIA driver chooses the placement of the various profiles. This can be seen in the following examples.

Example 1: Creation of a 4-2-1 geometry. After the instances are created, the placement of the profiles can be observed:

$ sudo nvidia-smi mig -cgi 19,14,5
Successfully created GPU instance ID 13 on GPU  0 using profile MIG 1g.5gb (ID 19)
Successfully created GPU instance ID  5 on GPU  0 using profile MIG 2g.10gb (ID 14)
Successfully created GPU instance ID  1 on GPU  0 using profile MIG 4g.20gb (ID  5)


$ sudo nvidia-smi mig -lgi
+----------------------------------------------------+
| GPU instances:                                     |
| GPU   Name          Profile  Instance   Placement  |
|                       ID       ID       Start:Size |
|====================================================|
|   0  MIG 1g.5gb       19       13          6:1     |
+----------------------------------------------------+
|   0  MIG 2g.10gb      14        5          4:2     |
+----------------------------------------------------+
|   0  MIG 4g.20gb       5        1          0:4     |
+----------------------------------------------------+
Example 2: Creation of a 3-2-1-1 geometry.

Note: Due to a known issue with the APIs, the profile ID 9 or 3g.20gb must be specified first in order. Not doing so, will result in the following error:

$ sudo nvidia-smi mig -cgi 19,19,14,9
Successfully created GPU instance ID 13 on GPU  0 using profile MIG 1g.5gb (ID 19)
Successfully created GPU instance ID 11 on GPU  0 using profile MIG 1g.5gb (ID 19)
Successfully created GPU instance ID  3 on GPU  0 using profile MIG 2g.10gb (ID 14)
Unable to create a GPU instance on GPU  0 using profile 9: Insufficient Resources
Failed to create GPU instances: Insufficient Resources
Specify the correct order for the 3g.20gb profile. The remaining combinations of the profiles do not have this requirement.

$ sudo nvidia-smi mig -cgi 9,19,14,19
Successfully created GPU instance ID  2 on GPU  0 using profile MIG 3g.20gb (ID  9)
Successfully created GPU instance ID  7 on GPU  0 using profile MIG 1g.5gb (ID 19)
Successfully created GPU instance ID  4 on GPU  0 using profile MIG 2g.10gb (ID 14)
Successfully created GPU instance ID  8 on GPU  0 using profile MIG 1g.5gb (ID 19)


$ sudo nvidia-smi mig -lgi
+----------------------------------------------------+
| GPU instances:                                     |
| GPU   Name          Profile  Instance   Placement  |
|                       ID       ID       Start:Size |
|====================================================|
|   0  MIG 1g.5gb       19        7          0:1     |
+----------------------------------------------------+
|   0  MIG 1g.5gb       19        8          1:1     |
+----------------------------------------------------+
|   0  MIG 2g.10gb      14        4          2:2     |
+----------------------------------------------------+
|   0  MIG 3g.20gb       9        2          4:4     |
+----------------------------------------------------+
Example 3: Creation of a 2-1-1-1-1-1 geometry:

$ sudo nvidia-smi mig -cgi 14,19,19,19,19,19
Successfully created GPU instance ID  5 on GPU  0 using profile MIG 2g.10gb (ID 14)
Successfully created GPU instance ID 13 on GPU  0 using profile MIG 1g.5gb (ID 19)
Successfully created GPU instance ID  7 on GPU  0 using profile MIG 1g.5gb (ID 19)
Successfully created GPU instance ID  8 on GPU  0 using profile MIG 1g.5gb (ID 19)
Successfully created GPU instance ID  9 on GPU  0 using profile MIG 1g.5gb (ID 19)
Successfully created GPU instance ID 10 on GPU  0 using profile MIG 1g.5gb (ID 19)


$ sudo nvidia-smi mig -lgi
+----------------------------------------------------+
| GPU instances:                                     |
| GPU   Name          Profile  Instance   Placement  |
|                       ID       ID       Start:Size |
|====================================================|
|   0  MIG 1g.5gb       19        7          0:1     |
+----------------------------------------------------+
|   0  MIG 1g.5gb       19        8          1:1     |
+----------------------------------------------------+
|   0  MIG 1g.5gb       19        9          2:1     |
+----------------------------------------------------+
|   0  MIG 1g.5gb       19       10          3:1     |
+----------------------------------------------------+
|   0  MIG 1g.5gb       19       13          6:1     |
+----------------------------------------------------+
|   0  MIG 2g.10gb      14        5          4:2     |
+----------------------------------------------------+
Running CUDA Applications on Bare-Metal
GPU Instances
The following example shows how two CUDA applications can be run in parallel on two different GPU instances. In this example, the BlackScholes CUDA sample is run simultaneously on the two GIs created on the A100.

$ nvidia-smi -L
GPU 0: A100-SXM4-40GB (UUID: GPU-e86cb44c-6756-fd30-cd4a-1e6da3caf9b0)
  MIG 3g.20gb Device 0: (UUID: MIG-c7384736-a75d-5afc-978f-d2f1294409fd)
  MIG 3g.20gb Device 1: (UUID: MIG-a28ad590-3fda-56dd-84fc-0a0b96edc58d)


$ CUDA_VISIBLE_DEVICES=MIG-c7384736-a75d-5afc-978f-d2f1294409fd ./BlackScholes &
$ CUDA_VISIBLE_DEVICES=MIG-a28ad590-3fda-56dd-84fc-0a0b96edc58d ./BlackScholes &
Now verify the two CUDA applications are running on two separate GPU instances:

$ nvidia-smi
+-----------------------------------------------------------------------------+
| MIG devices:                                                                |
+------------------+----------------------+-----------+-----------------------+
| GPU  GI  CI  MIG |         Memory-Usage |        Vol|         Shared        |
|      ID  ID  Dev |                      | SM     Unc| CE  ENC  DEC  OFA  JPG|
|                  |                      |        ECC|                       |
|==================+======================+===========+=======================|
|  0    1   0   0  |    268MiB / 20224MiB | 42      0 |  3   0    2    0    0 |
+------------------+----------------------+-----------+-----------------------+
|  0    2   0   1  |    268MiB / 20096MiB | 42      0 |  3   0    2    0    0 |
+------------------+----------------------+-----------+-----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                                  |
|  GPU   GI   CI        PID   Type   Process name                  GPU Memory |
|        ID   ID                                                   Usage      |
|=============================================================================|
|    0    1    0      58866      C   ./BlackScholes                    253MiB |
|    0    2    0      58856      C   ./BlackScholes                    253MiB |
+-----------------------------------------------------------------------------+
GPU Utilization Metrics
NVML (and nvidia-smi) does not support attribution of utilization metrics to MIG devices. From the previous example, the utilization is displayed as N/A when running CUDA programs:

$ nvidia-smi

+-----------------------------------------------------------------------------+
| MIG devices:                                                                |
+------------------+----------------------+-----------+-----------------------+
| GPU  GI  CI  MIG |         Memory-Usage |        Vol|         Shared        |
|      ID  ID  Dev |           BAR1-Usage | SM     Unc| CE  ENC  DEC  OFA  JPG|
|                  |                      |        ECC|                       |
|==================+======================+===========+=======================|
|  0    1   0   0  |    268MiB / 20096MiB | 42      0 |  3   0    2    0    0 |
|                  |      4MiB / 32767MiB |           |                       |
+------------------+----------------------+-----------+-----------------------+
|  0    2   0   1  |    268MiB / 20096MiB | 42      0 |  3   0    2    0    0 |
|                  |      4MiB / 32767MiB |           |                       |
+------------------+----------------------+-----------+-----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                                  |
|  GPU   GI   CI        PID   Type   Process name                  GPU Memory |
|        ID   ID                                                   Usage      |
|=============================================================================|
|    0    1    0       6217      C   ...inux/release/BlackScholes      253MiB |
|    0    2    0       6223      C   ...inux/release/BlackScholes      253MiB |
+-----------------------------------------------------------------------------+
For monitoring MIG devices on MIG capable GPUs such as the A100, including attribution of GPU metrics (including utilization and other profiling metrics), it is recommended to use NVIDIA DCGM v2.0.13 or later. See the Profiling Metrics section in the DCGM User Guide for more details on getting started.

Compute Instances
As explained earlier in this document, a further level of concurrency can be achieved by using Compute Instances (CIs). The following example shows how 3 CUDA processes (BlackScholes CUDA sample) can be run on the same GI.

First, list the available CI profiles available using our prior configuration of creating 2 GIs on the A100.

$ sudo nvidia-smi mig -lcip -gi 1
+--------------------------------------------------------------------------------------+
| Compute instance profiles:                                                           |
| GPU     GPU       Name             Profile  Instances   Exclusive       Shared       |
|       Instance                       ID     Free/Total     SM       DEC   ENC   OFA  |
|         ID                                                          CE    JPEG       |
|======================================================================================|
|   0      1       MIG 1c.3g.20gb       0      0/3           14        2     0     0   |
|                                                                      3     0         |
+--------------------------------------------------------------------------------------+
|   0      1       MIG 2c.3g.20gb       1      0/1           28        2     0     0   |
|                                                                      3     0         |
+--------------------------------------------------------------------------------------+
|   0      1       MIG 3g.20gb          2*     0/1           42        2     0     0   |
|                                                                      3     0         |
+--------------------------------------------------------------------------------------+
Create 3 CIs, each of type 1c compute capacity (profile ID 0) on the first GI.

$ sudo nvidia-smi mig -cci 0,0,0 -gi 1
Successfully created compute instance on GPU  0 GPU instance ID  1 using profile MIG 1c.3g.20gb (ID  0)
Successfully created compute instance on GPU  0 GPU instance ID  1 using profile MIG 1c.3g.20gb (ID  0)
Successfully created compute instance on GPU  0 GPU instance ID  1 using profile MIG 1c.3g.20gb (ID  0)
Using nvidia-smi, the following CIs are now created on GI 1:

$ sudo nvidia-smi mig -lci -gi 1
+-------------------------------------------------------+
| Compute instances:                                    |
| GPU     GPU       Name             Profile   Instance |
|       Instance                       ID        ID     |
|         ID                                            |
|=======================================================|
|   0      1       MIG 1c.3g.20gb       0         0     |
+-------------------------------------------------------+
|   0      1       MIG 1c.3g.20gb       0         1     |
+-------------------------------------------------------+
|   0      1       MIG 1c.3g.20gb       0         2     |
+-------------------------------------------------------+
And the GIs and CIs created on the A100 are now enumerated by the driver:

$ nvidia-smi
+-----------------------------------------------------------------------------+
| MIG devices:                                                                |
+------------------+----------------------+-----------+-----------------------+
| GPU  GI  CI  MIG |         Memory-Usage |        Vol|         Shared        |
|      ID  ID  Dev |                      | SM     Unc| CE  ENC  DEC  OFA  JPG|
|                  |                      |        ECC|                       |
|==================+======================+===========+=======================|
|  0    1   0   0  |     11MiB / 20224MiB | 14      0 |  3   0    2    0    0 |
+------------------+                      +-----------+-----------------------+
|  0    1   1   1  |                      | 14      0 |  3   0    2    0    0 |
+------------------+                      +-----------+-----------------------+
|  0    1   2   2  |                      | 14      0 |  3   0    2    0    0 |
+------------------+----------------------+-----------+-----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                                  |
|  GPU   GI   CI        PID   Type   Process name                  GPU Memory |
|        ID   ID                                                   Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+
Now, three BlackScholes applications can be created and run in parallel:

$ CUDA_VISIBLE_DEVICES=MIG-c7384736-a75d-5afc-978f-d2f1294409fd ./BlackScholes &
$ CUDA_VISIBLE_DEVICES=MIG-c376546e-7559-5610-9721-124e8dbb1bc8 ./BlackScholes &
$ CUDA_VISIBLE_DEVICES=MIG-928edfb0-898f-53bd-bf24-c7e5d08a6852 ./BlackScholes &
And seen using nvidia-smi as running processes on the three CIs:

$ nvidia-smi
+-----------------------------------------------------------------------------+
| MIG devices:                                                                |
+------------------+----------------------+-----------+-----------------------+
| GPU  GI  CI  MIG |         Memory-Usage |        Vol|         Shared        |
|      ID  ID  Dev |                      | SM     Unc| CE  ENC  DEC  OFA  JPG|
|                  |                      |        ECC|                       |
|==================+======================+===========+=======================|
|  0    1   0   0  |    476MiB / 20224MiB | 14      0 |  3   0    2    0    0 |
+------------------+                      +-----------+-----------------------+
|  0    1   1   1  |                      | 14      0 |  3   0    2    0    0 |
+------------------+                      +-----------+-----------------------+
|  0    1   2   2  |                      | 14      0 |  3   0    2    0    0 |
+------------------+----------------------+-----------+-----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                                  |
|  GPU   GI   CI        PID   Type   Process name                  GPU Memory |
|        ID   ID                                                   Usage      |
|=============================================================================|
|    0    1    0      59785      C   ./BlackScholes                    153MiB |
|    0    1    1      59796      C   ./BlackScholes                    153MiB |
|    0    1    2      59885      C   ./BlackScholes                    153MiB |
+-----------------------------------------------------------------------------+
Destroying GPU Instances
Once the GPU is in MIG mode, GIs and CIs can be configured dynamically. The following example shows how the CIs and GIs created in the previous examples can be destroyed.

Note: If the intention is to destroy all the CIs and GIs, then this can be accomplished with the following commands:

$ sudo nvidia-smi mig -dci && sudo nvidia-smi mig -dgi
Successfully destroyed compute instance ID  0 from GPU  0 GPU instance ID  1
Successfully destroyed compute instance ID  1 from GPU  0 GPU instance ID  1
Successfully destroyed compute instance ID  2 from GPU  0 GPU instance ID  1
Successfully destroyed GPU instance ID  1 from GPU  0
Successfully destroyed GPU instance ID  2 from GPU  0
In this example, we delete the specific CIs created under GI 1.

$ sudo nvidia-smi mig -dci -ci 0,1,2 -gi 1
Successfully destroyed compute instance ID  0 from GPU  0 GPU instance ID  1
Successfully destroyed compute instance ID  1 from GPU  0 GPU instance ID  1
Successfully destroyed compute instance ID  2 from GPU  0 GPU instance ID  1
It can be verified that the CI devices have now been torn down on the GPU:

$ nvidia-smi
+-----------------------------------------------------------------------------+
| MIG devices:                                                                |
+------------------+----------------------+-----------+-----------------------+
| GPU  GI  CI  MIG |         Memory-Usage |        Vol|         Shared        |
|      ID  ID  Dev |                      | SM     Unc| CE  ENC  DEC  OFA  JPG|
|                  |                      |        ECC|                       |
|==================+======================+===========+=======================|
|  No MIG devices found                                                       |
+-----------------------------------------------------------------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                                  |
|  GPU   GI   CI        PID   Type   Process name                  GPU Memory |
|        ID   ID                                                   Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+
Now the GIs have to be deleted:

$ sudo nvidia-smi mig -dgi
Successfully destroyed GPU instance ID  1 from GPU  0
Successfully destroyed GPU instance ID  2 from GPU  0
Monitoring MIG Devices
For monitoring MIG devices on including attribution of GPU metrics (including utilization and other profiling metrics), it is recommended to use NVIDIA DCGM v3 or later. See the Profiling Metrics section in the DCGM User Guide for more details on getting started.

Note

On NVIDIA Ampere architecture GPUs (A100 or A30), NVML (and nvidia-smi) does not support attribution of utilization metrics to MIG devices. From the previous example, the utilization is displayed as N/A when running CUDA programs:

$ nvidia-smi

+-----------------------------------------------------------------------------+
| MIG devices:                                                                |
+------------------+----------------------+-----------+-----------------------+
| GPU  GI  CI  MIG |         Memory-Usage |        Vol|         Shared        |
|      ID  ID  Dev |           BAR1-Usage | SM     Unc| CE  ENC  DEC  OFA  JPG|
|                  |                      |        ECC|                       |
|==================+======================+===========+=======================|
|  0    1   0   0  |    268MiB / 20096MiB | 42      0 |  3   0    2    0    0 |
|                  |      4MiB / 32767MiB |           |                       |
+------------------+----------------------+-----------+-----------------------+
|  0    2   0   1  |    268MiB / 20096MiB | 42      0 |  3   0    2    0    0 |
|                  |      4MiB / 32767MiB |           |                       |
+------------------+----------------------+-----------+-----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                                  |
|  GPU   GI   CI        PID   Type   Process name                  GPU Memory |
|        ID   ID                                                   Usage      |
|=============================================================================|
|    0    1    0       6217      C   ...inux/release/BlackScholes      253MiB |
|    0    2    0       6223      C   ...inux/release/BlackScholes      253MiB |
+-----------------------------------------------------------------------------+
MIG with CUDA MPS
As described in CUDA Concurrency Mechanisms, CUDA Multi-Process Service (MPS) enables co-operative multi-process CUDA applications to be processed concurrently on the GPU. MPS and MIG can work together, potentially achieving even higher levels of utilization for certain workloads.

Refer to the MPS documentation to understand the architecture and provisioning sequence for MPS.

In the following sections, we will walk through an example of running MPS on MIG devices.

Workflow
In summary, the workflow for running with MPS is as follows:

Configure the desired MIG geometry on the GPU.

Setup the CUDA_MPS_PIPE_DIRECTORY variable to point to unique directories so that the multiple MPS servers and clients can communicate with each other using named pipes and Unix domain sockets.

Launch the application by specifying the MIG device using CUDA_VISIBLE_DEVICES.

Note

The MPS documentation recommends setting up EXCLUSIVE_PROCESS mode to ensure that a single MPS server is using the GPU. However, this mode is not supported when the GPU is in MIG mode as we use multiple MPS servers (one per MIG GPU instance).

Configure GPU Instances
Follow the steps outlined in the previous sections to configure the desired MIG geometry on the GPU. For this example, we configure the GPU into a 3g.40gb, 3g.40gb geometry:

Create GPU and compute instances:

sudo nvidia-smi mig -cgi 9,9 -C
Successfully created GPU instance ID  2 on GPU  0 using profile MIG 3g.40gb (ID  9)
Successfully created compute instance ID  0 on GPU  0 GPU instance ID  2 using profile MIG 3g.40gb (ID  2)
Successfully created GPU instance ID  1 on GPU  0 using profile MIG 3g.40gb (ID  9)
Successfully created compute instance ID  0 on GPU  0 GPU instance ID  1 using profile MIG 3g.40gb (ID  2)
Verify configuration:

nvidia-smi

+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 580.65.06              Driver Version: 580.65.06      CUDA Version: 13.0     |
+-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA H100 80GB HBM3          Off |   00000000:42:00.0 Off |                   On |
| N/A   30C    P0            141W /  700W |      87MiB /  81559MiB |     N/A      Default |
|                                         |                        |              Enabled |
+-----------------------------------------+------------------------+----------------------+

+-----------------------------------------------------------------------------------------+
| MIG devices:                                                                            |
+------------------+----------------------------------+-----------+-----------------------+
| GPU  GI  CI  MIG |              Shared Memory-Usage |        Vol|        Shared         |
|      ID  ID  Dev |                Shared BAR1-Usage | SM     Unc| CE ENC  DEC  OFA  JPG |
|                  |                                  |        ECC|                       |
|==================+==================================+===========+=======================|
|  0    1   0   0  |              44MiB / 40448MiB    | 60      0 |  3   0    3    0    3 |
|                  |               0MiB / 24740MiB    |           |                       |
+------------------+----------------------------------+-----------+-----------------------+
|  0    2   0   1  |              44MiB / 40448MiB    | 60      0 |  3   0    3    0    3 |
|                  |               0MiB / 24740MiB    |           |                       |
+------------------+----------------------------------+-----------+-----------------------+
Set Up the MPS Control Daemons
In this step, we start an MPS control daemon (with admin privileges) and ensure we use a different socket for each daemon:

export CUDA_MPS_PIPE_DIRECTORY=/tmp/<MIG_UUID>
mkdir -p $CUDA_MPS_PIPE_DIRECTORY

CUDA_VISIBLE_DEVICES=<MIG_UUID> \
CUDA_MPS_PIPE_DIRECTORY=/tmp/<MIG_UUID> \
nvidia-cuda-mps-control -d
Launch the Application
Now we can launch the application by specifying the desired MIG device using CUDA_VISIBLE_DEVICES:

CUDA_VISIBLE_DEVICES=<MIG_UUID> \
   my-cuda-app
A Complete Example
The following script runs the BlackScholes sample on the two MIG devices created on the GPU. It starts a separate MPS control daemon per MIG device and launches the workload on each device.

#!/usr/bin/env bash
set -euo pipefail

# GPU 0: NVIDIA H100 80GB HBM3 (UUID: GPU-c08d91cb-e324-655c-71ba-7570956445bc)
#   MIG 3g.40gb     Device  0: (UUID: MIG-405bbda1-6b05-535f-9702-f95e8cd170ce)
#   MIG 3g.40gb     Device  1: (UUID: MIG-b0a55a70-b1b0-529f-af26-79ccdc267be0)

MIG_DEVICES=(
   "MIG-405bbda1-6b05-535f-9702-f95e8cd170ce"
   "MIG-b0a55a70-b1b0-529f-af26-79ccdc267be0"
)

for mig_device in "${MIG_DEVICES[@]}"; do
  # Set a unique pipe directory and start an MPS control daemon per MIG instance
  export CUDA_MPS_PIPE_DIRECTORY=/tmp/$mig_device
  mkdir -p "$CUDA_MPS_PIPE_DIRECTORY"
  sudo CUDA_VISIBLE_DEVICES=$mig_device \
       CUDA_MPS_PIPE_DIRECTORY=/tmp/$mig_device \
       nvidia-cuda-mps-control -d

  # Launch the job on the specific MIG device and point to the matching MPS server
  CUDA_MPS_PIPE_DIRECTORY=/tmp/$mig_device \
  CUDA_VISIBLE_DEVICES=$mig_device \
  ./bin/BlackScholes &
done
When the script is running, you should see two MPS servers and the corresponding CUDA programs as MPS clients using nvidia-smi:

+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
|    0    1    0             3805    M+C   ./bin/BlackScholes                      326MiB |
|    0    1    0             3809      C   nvidia-cuda-mps-server                   60MiB |
|    0    2    0             3817    M+C   ./bin/BlackScholes                      326MiB |
|    0    2    0             3819      C   nvidia-cuda-mps-server                   60MiB |
+-----------------------------------------------------------------------------------------+
Running CUDA Applications as Containers
NVIDIA Container Toolkit has been enhanced to provide support for MIG devices, allowing users to run GPU containers with runtimes such as Docker. This section provides an overview of running Docker containers on A100 with MIG.

Install Docker
Many Linux distributions may come with Docker-CE pre-installed. If not, use the Docker installation script to install Docker.

$ curl https://get.docker.com | sh \
    && sudo systemctl start docker \
    && sudo systemctl enable docker
Install NVIDIA Container Toolkit
Now install the NVIDIA Container Toolkit (previously known as nvidia-docker2).

To get access to the /dev nvidia capabilities, it is recommended to use at least v2.5.0 of nvidia-docker2. Refer to the Installation Guide for more information.

For brevity, the installation instructions provided here are for Ubuntu 18.04 LTS. Refer to the NVIDIA Container Toolkit page for instructions on other Linux distributions.

Setup the repository and the GPG key:

$ distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
      && curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
      && curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
            sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
            sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
Install the NVIDIA Container Toolkit packages (and their dependencies):

$ sudo apt-get install -y nvidia-docker2 \
    && sudo systemctl restart docker
Running Containers
To run containers on specific MIG devices – whether these are GIs or specific underlying CIs, then the NVIDIA_VISIBLE_DEVICES variable (or the --gpus option with Docker 19.03+) can be used. NVIDIA_VISIBLE_DEVICES supports the following formats to specify MIG devices:

MIG-<GPU-UUID>/<GPU instance ID>/<compute instance ID> when using R450 and R460 drivers or MIG-<UUID> starting with R470 drivers.

GPUDeviceIndex>:<MIGDeviceIndex>

If using Docker 19.03, the --gpus option can be used to specify MIG devices by using the following format: "device=MIG-device", where MIG-device can follow either of the format specified above for NVIDIA_VISIBLE_DEVICES.

The following example shows running nvidia-smi from within a CUDA container using both formats. As can be seen in the example, only one MIG device as chosen is visible to the container when using either format.

$ sudo docker run --runtime=nvidia \
    -e NVIDIA_VISIBLE_DEVICES=MIG-c7384736-a75d-5afc-978f-d2f1294409fd \
    nvidia/cuda nvidia-smi

+-----------------------------------------------------------------------------+
| MIG devices:                                                                |
+------------------+----------------------+-----------+-----------------------+
| GPU  GI  CI  MIG |         Memory-Usage |        Vol|         Shared        |
|      ID  ID  Dev |                      | SM     Unc| CE  ENC  DEC  OFA  JPG|
|                  |                      |        ECC|                       |
|==================+======================+===========+=======================|
|  0    1   0   0  |     11MiB / 20224MiB | 42      0 |  3   0    2    0    0 |
+------------------+----------------------+-----------+-----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                                  |
|  GPU   GI   CI        PID   Type   Process name                  GPU Memory |
|        ID   ID                                                   Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+


# For Docker versions < 19.03
$ sudo docker run --runtime=nvidia \
    -e NVIDIA_VISIBLE_DEVICES="0:0" \
    nvidia/cuda nvidia-smi -L
GPU 0: A100-SXM4-40GB (UUID: GPU-e86cb44c-6756-fd30-cd4a-1e6da3caf9b0)
  MIG 3g.20gb Device 0: (UUID: MIG-c7384736-a75d-5afc-978f-d2f1294409fd)


# For Docker versions >= 19.03
$ sudo docker run --gpus '"device=0:0"' \
    nvidia/cuda nvidia-smi -L
GPU 0: A100-SXM4-40GB (UUID: GPU-e86cb44c-6756-fd30-cd4a-1e6da3caf9b0)
  MIG 3g.20gb Device 0: (UUID: MIG-c7384736-a75d-5afc-978f-d2f1294409fd)
A more complex example is to run a TensorFlow container to do a training run using GPUs on the MNIST dataset. This is shown below:

$ sudo docker run --gpus '"device=0:1"' \
    nvcr.io/nvidia/pytorch:20.11-py3 \
    /bin/bash -c 'cd /opt/pytorch/examples/upstream/mnist && python main.py'

=============
== PyTorch ==
=============

NVIDIA Release 20.11 (build 17345815)
PyTorch Version 1.8.0a0+17f8c32

Container image Copyright (c) 2020, NVIDIA CORPORATION.  All rights reserved.

Copyright (c) 2014-2020 Facebook Inc.
Copyright (c) 2011-2014 Idiap Research Institute (Ronan Collobert)
Copyright (c) 2012-2014 Deepmind Technologies    (Koray Kavukcuoglu)
Copyright (c) 2011-2012 NEC Laboratories America (Koray Kavukcuoglu)
Copyright (c) 2011-2013 NYU                      (Clement Farabet)
Copyright (c) 2006-2010 NEC Laboratories America (Ronan Collobert, Leon Bottou, Iain Melvin, Jason Weston)
Copyright (c) 2006      Idiap Research Institute (Samy Bengio)
Copyright (c) 2001-2004 Idiap Research Institute (Ronan Collobert, Samy Bengio, Johnny Mariethoz)
Copyright (c) 2015      Google Inc.
Copyright (c) 2015      Yangqing Jia
Copyright (c) 2013-2016 The Caffe contributors
All rights reserved.

NVIDIA Deep Learning Profiler (dlprof) Copyright (c) 2020, NVIDIA CORPORATION.  All rights reserved.

Various files include modifications (c) NVIDIA CORPORATION.  All rights reserved.
NVIDIA modifications are covered by the license terms that apply to the underlying project or file.

NOTE: Legacy NVIDIA Driver detected.  Compatibility mode ENABLED.

9920512it [00:01, 7880654.53it/s]
32768it [00:00, 129950.31it/s]
1654784it [00:00, 2353765.88it/s]
8192it [00:00, 41020.33it/s]
/opt/conda/lib/python3.6/site-packages/torchvision/datasets/mnist.py:480: UserWarning: The given NumPy array is not writeable, and PyTorch does not support non-writeable tensors. This means you can write to the underlying (supposedly non-writeable) NumPy array using the tensor. You may want to copy the array to protect its data or make it writeable before converting it to a tensor. This type of warning will be suppressed for the rest of this program. (Triggered internally at  ../torch/csrc/utils/tensor_numpy.cpp:141.)
  return torch.from_numpy(parsed.astype(m[2], copy=False)).view(*s)
Downloading http://yann.lecun.com/exdb/mnist/train-images-idx3-ubyte.gz to ../data/MNIST/raw/train-images-idx3-ubyte.gz
Extracting ../data/MNIST/raw/train-images-idx3-ubyte.gz to ../data/MNIST/raw
Downloading http://yann.lecun.com/exdb/mnist/train-labels-idx1-ubyte.gz to ../data/MNIST/raw/train-labels-idx1-ubyte.gz
Extracting ../data/MNIST/raw/train-labels-idx1-ubyte.gz to ../data/MNIST/raw
Downloading http://yann.lecun.com/exdb/mnist/t10k-images-idx3-ubyte.gz to ../data/MNIST/raw/t10k-images-idx3-ubyte.gz
Extracting ../data/MNIST/raw/t10k-images-idx3-ubyte.gz to ../data/MNIST/raw
Downloading http://yann.lecun.com/exdb/mnist/t10k-labels-idx1-ubyte.gz to ../data/MNIST/raw/t10k-labels-idx1-ubyte.gz
Extracting ../data/MNIST/raw/t10k-labels-idx1-ubyte.gz to ../data/MNIST/raw
Processing...
Done!
Train Epoch: 1 [0/60000 (0%)]   Loss: 2.320747
Train Epoch: 1 [640/60000 (1%)] Loss: 1.278727
MIG with Kubernetes
MIG support in Kubernetes is available starting with v0.7.0 of the NVIDIA Device Plugin for Kubernetes. Visit the documentation on getting started with MIG and Kubernetes.

MIG with Slurm
Slurm is a workload manager that is widely used at high performance computing centers such as government labs, universities.

Starting with 21.08, Slurm supports the usage of MIG devices. Refer to the official documentation on getting started.

previous

Supported MIG Profiles

next

Device Nodes and Capabilities

 On this page
Prerequisites
Enable MIG Mode
List GPU Instance Profiles
Creating GPU Instances
Running CUDA Applications on Bare-Metal
Destroying GPU Instances
Monitoring MIG Devices
MIG with CUDA MPS
Workflow
Configure GPU Instances
Set Up the MPS Control Daemons
Launch the Application
A Complete Example
Running CUDA Applications as Containers
MIG with Kubernetes
MIG with Slurm

Feedback
