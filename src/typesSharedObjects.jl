#
# types.jl --
#
# Type definitions for the Julia interface to the C libraries of TAO, a Toolkit
# for Adaptive Optics.
#
#------------------------------------------------------------------------------
#
# This file is part of TAO software (https://git-cral.univ-lyon1.fr/tao)
# licensed under the MIT license.
#
# Copyright (C) 2018-2021, Éric Thiébaut.
#
"""

Type `Tao.AbstractCamera{T}` is the super-type of camera and image provider
concrete types in TAO.  Parameter `T` is the pixel type of the acquired images
or `Any` when the pixel type is unknown or undetermined.

"""
abstract type AbstractCamera{T} end


"""
    TaoBindings.LockMode(val)

is used to denote the lock mode of a lockable object (see
[`TaoBindings.Lockable`](@ref)).  Constants `TaoBindings.UNLOCKED`
`TaoBindings.READ_ONLY`, and `TaoBindings.READ_WRITE` are the different
possibilities.

"""
struct LockMode
    mode::Cint
end

const UNLOCKED   = LockMode(0)
const READ_ONLY  = LockMode(1)
const READ_WRITE = LockMode(2)

"""

`TaoBindings.AbstractSharedObject` is the super-type of all objects stored in
shared memory.

"""
abstract type AbstractSharedObject end


"""

Type `TaoBindings.SharedObject` is used to represent a generic shared TAO
object in Julia.  TAO shared objects implement the `obj.key` syntax with the
following properties:

| Name              | Const. | Description                                                |
|:------------------|:-------|:-----------------------------------------------------------|
| `accesspoint`     | yes    | Address of the server owning the object                    |
| `lock`            | no     | Type of lock owned by the caller                           |
| `owner`           | yes    | Name of the server owning the object                       |
| `shmid`           | yes    | Identifier of the shared memory segment storing the object |
| `size`            | yes    | Number of bytes allocated for the shared object            |
| `type`            | yes    | Type identifier of the shared object                       |

Column *Const.* indicates whether the property is constant during shared object
lifetime.

!!! warn
        Properties should all be considered as read-only by the end-user and never
    directly modified or unexpected behavior may occur.

"""
mutable struct SharedObject <: AbstractSharedObject
    ptr::Ptr{AbstractSharedObject}
    lock::LockMode
    final::Bool    # a finalizer has been installed
    # Provide a unique inner constructor which forces starting with a NULL
    # pointer and no finalizer.
    SharedObject() = new(C_NULL, UNLOCKED, false)
end

"""

Type `TaoBindings.SharedArray{T,N}` is a concrete subtype of `DenseArray{T,N}`
which includes all arrays where elements are stored contiguously in
column-major order.  TAO shared arrrays implement the `arr.key` syntax with the
following properties:

| Name              | Const. | Description                                                |
|:------------------|:-------|:-----------------------------------------------------------|
| `accesspoint`     | yes    | Address of the server owning the object                    |
| `counter`         | no     | Serial number of the shared array                          |
| `lock`            | no     | Type of lock owned by the caller                           |
| `owner`           | yes    | Name of the server owning the object                       |
| `shmid`           | yes    | Identifier of the shared memory segment storing the object |
| `size`            | yes    | Number of bytes allocated for the shared object            |
| `timestamp`       | no     | Time-stamp  of the shared array                            |
| `type`            | yes    | Type identifier of the shared object                       |

Column *Const.* indicates whether the property is constant during shared object lifetime.

!!! warn
    Properties should all be considered as read-only by the end-user and never
    directly modified or unexpected behavior may occur.

"""
mutable struct SharedArray{T,N} <: DenseArray{T,N}
    ptr::Ptr{AbstractSharedObject}
    arr::Array{T,N}
    lock::LockMode
    final::Bool    # a finalizer has been installed
end


"""
    SpinnakerCameras.RemoteCameraState
    enumeration of the RemoteCamera States

""" RemoteCameraState
struct RemoteCameraState
    state::Cint
end
const STATE_UNKNOWN = RemoteCameraState(0)
const STATE_INIT    = RemoteCameraState(1)
const STATE_WAIT    = RemoteCameraState(2)
const STATE_ERROR   = RemoteCameraState(3)
const STATE_WORK    = RemoteCameraState(4)
const STATE_QUIT    = RemoteCameraState(5)

"""
    SpinnakercCameras.RemoteCameraCommand
enumeration of the Remote Camera Commands

""" RemoteCameraCommand
struct RemoteCameraCommand
    cmd::Cint
end

const   CMD_INIT  = RemoteCameraCommand(0)
const   CMD_WAIT  = RemoteCameraCommand(1)
const   CMD_WORK = RemoteCameraCommand(2)
const   CMD_STOP  = RemoteCameraCommand(3)
const   CMD_ABORT  = RemoteCameraCommand(4)
const   CMD_QUIT  = RemoteCameraCommand(5)


struct ShCamSIG
    sig::Cint
end
const   SIG_DONE = ShCamSIG(0)
const   SIG_OK = ShCamSIG(1)
const   SIG_ERROR = ShCamSIG(2)

"""

Type `TaoBindings.SharedCamera` is used to represent shared camera data in
Julia. It served as an interface to camera's configuration within a camera server.
A shared camera instance implements the `cam.key` syntax with the following
public properties:

| Name              | Const. | Description                                                |
|:------------------|:-------|:-----------------------------------------------------------|
| `accesspoint`     | yes    | Address of the server owning the object                    |
| `bufferrencoding` | no     | Encoding of the camera acquisition buffers                 |
| `counter`         | no     | Counter of the last acquired frame                         |
| `exposuretime`    | no     | Exposure time in seconds per frame                         |
| `framerate`       | no     | Frames per second                                          |
| `height`          | no     | Height of the ROI in macro pixels                          |
| `last`            | no     | Shared memory identifier of the last acquired image        |
| `listlength`      | yes    | Number of shared images memorized by the camera owner      |
| `lock`            | no     | Type of lock owned by the caller                           |
| `next`            | no     | Shared memory identifier of the next acquired image        |
| `owner`           | yes    | Name of the server owning the object                       |
| `pixeltype`       | no     | Pixel type of the axquired images                          |
| `sensorencoding`  | no     | Encoding of the pixel data sent by the device              |
| `sensorheight`    | yes    | Number of rows of physical pixels of the sensor            |
| `sensorwidth`     | yes    | Number of physical pixels per row of the sensor            |
| `shmid`           | yes    | Identifier of the shared memory segment storing the object |
| `size`            | yes    | Number of bytes allocated for the shared object            |
| `state`           | no     | State of the remote camera                                 |
| `type`            | yes    | Type identifier of the shared object                       |
| `width`           | no     | Width of the ROI in macro pixels                           |
| `xbin`            | no     | Horizontal binning factor                                  |
| `xoff`            | no     | Horizontal offset of the ROI                               |
| `ybin`            | no     | Vertical binning factor                                    |
| `yoff`            | no     | Vertical offset of the ROI                                 |

Notes: *ROI* is the Region Of Interest of the acquired image.  ROI offsets are
a number of physical pixels.  Binning factors are in physical pixels per macro
pixel.  Column *Const.* indicates whether the property is constant during
shared object lifetime.  To make sure that the values of non-immutable fields
are consistent, the camera should be locked by the caller.  For example:

    timeout = 30.0 # 30 seconds timeout
    if rdlock(cam, timeout)
        # Camera `cam` has been succesfuly locked for read-only access.
        stat = cam.state
        counter = cam.counter
        last = cam.last
        unlock(cam) # do not forget to release the lock as soon as possible
    else
        # Time-out occured before read-only access can be granted.
        ...
    end

!!! warn
    Properties should all be considered as read-only by the end-user and never
    directly modified or unexpected behavior may occur.

"""
mutable struct SharedCamera <: AbstractCamera{Any}

    ptr::Ptr{AbstractSharedObject}
    img_config::ImageConfigContext  # file
    attachedCam::Int8
    cameras::Vector{Camera}

    listlength::Int8        # number of images memorized my the camera owner
    last::Int16
    next::Int16
    lastTS::Int16
    nextTS::Int16

    lock::LockMode
    final::Bool    # a finalizer has been installed

    # Provide a unique inner constructor which forces starting with a NULL
    # pointer and no finalizer.
    SharedCamera() = new(C_NULL,ImageConfigContext(),0,Vector{Camera}(undef,5),5,1,0,0,0,UNLOCKED, false)
end


# The following is to have a complete signature for type statbility.
const DynamicArray{T,N} = ResizableArray{T,N,Vector{T}}

"""
    RemoteCamera{T}(dev) -> cam

wraps TAO shared camera `dev` into a higher level camera instance.  The camera
instance `dev` can also be replaced by the remote camera name.  For instance:

    cam = RemoteCamera{T}("TAO:SpinnakerCameras")

The parameter `T` is the pixel type of the acquired images.  If not specified,
it is obtained from the associated shared camera.  In any cases, it will be
asserted that `T` matches the element type of the shared arrays storing the
acquired images (and their weights).

The remote camera `cam` always provides images of element type `T` using the
connected remote camera to get/wait images.  It takes care of avoiding
attaching shared images by maintaining a mirror of the list of shared images
stored by the virtual frame-grabber owning the remote camera.  This saves the
time of attaching shared arrays.  This also avoid critical issues in a
continuous processing loop because Julia garbage collector may not finalize
(hence detach) attached arrays fast enough and their number of attachments will
therefore grow indefinitely until resources are exhausted.

The remote camera `cam` may be used as an iterator which provides images until
the acquisition is stopped (by someone else).

Compared to shared cameras (of type [`TaoBindings.SharedCamera`](@ref)),
remotes cameras (of type `RemoteCamera`) are needed to:

- provide type-stability (i.e., pixel type is known);
- preprocess images (if not yet done by the server);
- hide the list of attached shared arrays;
- avoid re-allocating resources as much as possible.

A remote camera instance implements the `cam.key` syntax with the same public
properties as a shared camera plus `cam.cached_image`
which are arrays used to store the image


| Name              | Const. | Description                                                |
|:------------------|:-------|:-----------------------------------------------------------|
| `cached_image`    | no     | Image ready to be grabed                         |

"""


mutable struct RemoteCamera{T<:Number} <: AbstractCamera{T}
    arrays::Vector{Array{T,2}} # list of attached shared arrays
    shmids::Vector{ShmId}            # list of corresponding identifiers
    timestamps::Vector{UInt64}         # list of timestamps of the shared array
    device::SharedCamera             # connection to remote camera

    time_origin::HighResolutionTime     # timestamp when the server is up

    img::SharedArray{T,2}                # last image
    imgTime::SharedArray{UInt64,1}       # last image timestamp

    function RemoteCamera{T}(device::SharedCamera,dims::NTuple{2,Int64}) where {T<:Number}
        isconcretetype(T) || error("pixel type $T must be concrete")
        len = Int(device.listlength)
        arrays = fill!(Vector{Array{T,2}}(undef, len),zeros(dims))
        shmids = fill!(Vector{ShmId}(undef, len), -1)
        timestamps = fill!(Vector{UInt64}(undef,len), 0)


        imgBuff = create(SharedArray{T,2},dims)
        img = attach(SharedArray, imgBuff.shmid)

        imgTimeBuff = create(SharedArray{UInt64,1},1)
        imgTime = attach(SharedArray, imgTimeBuff.shmid)

        wrlock(img, 0.5) do
            fill!(img,convert(T,0))
        end

        wrlock(imgTime, 0.5) do
            fill!(imgTime,0)
        end

        return new{T}(arrays, shmids, timestamps, device,HighResolutionTime(0,0),img,imgTime)
    end
end

const RemoteCameraOutput{T} = DynamicArray{T,2}
const RemoteCameraOutputs{N,T} = NTuple{N,DynamicArray{T,2}}
#--- Monitor
_to_Cint(state::RemoteCameraState) =  state.state
_to_Cint(cmd::RemoteCameraCommand) =  cmd.cmd
_to_Cint(sig::ShCamSIG) = sig.sig

abstract type AbstractMonitor end

mutable struct RemoteCameraMonitor <: AbstractMonitor
    ptr::Ptr{AbstractSharedObject}  # to access mutex lock capability only
    final::Bool

    cmds::SharedArray{Cint,1}
    state::SharedArray{Cint,1}
    fetch_index::Int64
    release_counter::Int64
    procedures::Vector{Function}

    empty_cmds::Condition
    wait_to_fetch::Condition
    fetch_index_updated::Condition
    fetch_index_read::Condition

    lock::LockMode

    function RemoteCameraMonitor(p_list::Vector{Function})
        # check the condition of th eprocedure list

        cmds_pre = create(SharedArray{Cint,1},4)
        cmds = attach(SharedArray,cmds_pre.shmid)
        wrlock(cmds) do
            fill!(cmds,-1)
        end

        state_pre = create(SharedArray{Cint,1},1)
        state = attach(SharedArray, state_pre.shmid)
        wrlock(state) do
            fill!(state,-1)
        end

         return new(C_NULL,false,cmds, state,1, 1,p_list,Condition(), Condition(),Condition(),Condition(),UNLOCKED )
    end

end

iscmdempty(monitor::RemoteCameraMonitor) = begin
        if !islocked(monitor)
            try
                rdlock(monitor)
                cmds = copy(monitor.cmds)
            finally
                unlock(monitor)
            end
        else
            cmds = copy(monitor.cmds)
        end

        return (sum(cmds .== undef) == 0) ?  true :  false

end

function monitor_read_cmd(monitor::RemoteCameraMonitor)
    cmd = copy(monitor.cmds[1])
    return RemoteCameraCommand(cmd)
end

function monitor_read_state(monitor::RemoteCameraMonitor)
    state = copy(monitor.state[1])
    return RemoteCameraState(state)
end

function monitor_write_cmd!(monitor::RemoteCameraMonitor, val::Vector{RemoteCameraCommand})
    # if the cmds is not empty => can't write
    val = map(_to_Cint,val)
    length(val) <= length(monitor.cmds) ||throw(ArgumentError("too many commands"))
    iscmdempty(monitor) == true ||  @warn "the command list is not empty. Can't write to"
    monitor.cmds[1:length(val)] = val[:]
    nothing

end

monitor_write_state!(monitor::RemoteCameraMonitor, val::RemoteCameraState) = begin
                                        copyto!(monitor.state,_to_Cint(val))
                                        nothing
                                    end

function monitor_push_cmd!(monitor::RemoteCameraMonitor)
        tmp = monitor.cmds[2:end]
        monitor.cmds[1:end] = vcat(tmp, [-1])
        nothing
end

function monitor_clear_state!(monitor::RemoteCameraMonitor)
    monitor.state[1] = -1
end
read_rcounter(monitor::RemoteCameraMonitor) = monitor.release_counter

inc_rcounter!(monitor::RemoteCameraMonitor) = monitor.release_counter+1

const default_P_list =[ monitor_read_cmd,   monitor_write_cmd!,
                        monitor_read_state, monitor_write_state!,
                        monitor_push_cmd!,  monitor_clear_state!    ]


##
mutable struct SharedCameraMonitor <: AbstractMonitor
    ptr::Ptr{AbstractSharedObject}  # to access mutex lock capability only
    final::Bool

    cmd::RemoteCameraCommand
    start_status::ShCamSIG
    completion::ShCamSIG
    image_counter::Int64
    procedures::Vector{Function}

    no_cmd::Condition
    not_started::Condition
    state_updating::Condition
    not_complete::Condition

    lock::LockMode

    SharedCameraMonitor(p_list::Vector{Function}) = new(C_NULL,false,
    RemoteCameraCommand(-1), ShCamSIG(-1),ShCamSIG(-1),0, p_list,Condition(),
    Condition(),Condition(),Condition(),UNLOCKED )

end

function monitor_read_cmd(monitor::SharedCameraMonitor)
    cmd = copy(monitor.cmd[1])
    return RemoteCameraCommand(cmd)
end
function monitor_write_cmd!(monitor::SharedCameraMonitor, val::RemoteCameraCommand)
    # if the cmds is not empty => can't write
    monitor.cmd == RemoteCameraCommand(-1) ||  @warn "the shared camera can't receive command yet"
    monitor.cmd = val
    notify(monitor.no_cmd)
    nothing
end

function monitor_read_start_status(monitor::SharedCameraMonitor)
    st = copy(monitor.start_status)
    return st
end
function monitor_write_start_status!(monitor::SharedCameraMonitor, val::ShCamSIG)
    copyto!(monitor.start_status,val)
    notify(not_started)
    nothing
end

function monitor_read_completion(monitor::SharedCameraMonitor)
    st = copy(monitor.completion)
    return st
end
function monitor_write_completion!(monitor::SharedCameraMonitor, val::ShCamSIG)
    copyto!(monitor.completion,val)
    notify(not_complete)
    nothing
end

function monitor_reset_cmd!(monitor::SharedCameraMonitor)
    monitor.cmd = RemoteCameraCommand(-1)
    nothing
end

const default_p_list_sh = [ monitor_read_cmd,           monitor_write_cmd!,
                            monitor_read_start_status,  monitor_write_start_status!,
                            monitor_read_completion,    monitor_write_completion!,
                            monitor_reset_cmd!  ]


"""

`TaoBindings.Lockable` is the union of types of TAO objects that implement
read/write locks.  Methods [`TaoBindings.rdlock`](@ref),
[`TaoBindings.wrlock`](@ref), [`TaoBindings.unlock`](@ref), and
[`TaoBindings.islocked`](@ref) are applicable to such objects.

"""
const Lockable = Union{AbstractSharedObject,SharedArray,AbstractMonitor,RemoteCamera, SharedCamera}


"""

Union `TaoBindings.AnySharedObject` is defined to represent any shared objects
in `TaoBindings` because shared arrays and shared cameras inherit from
`DenseArray` and `AbstractCamera` respectively, not from
`TaoBindings.AbstractSharedObject`.

"""
const AnySharedObject = Union{AbstractSharedObject,SharedArray,SharedCamera,RemoteCamera,AbstractMonitor}

const TaoSharedObject = Union{AbstractSharedObject,SharedArray}


"""
The singleton type `Basic` is a *trait* used to indicate that the version
provided by Julia must be used for a vectorized method.

This *hack* is to avoid calling methods that may be inefficient in a specific
context.  For instance BLAS `lmul!(A,B)` for small arrays.

"""
struct Basic end
