#
# methods.jl -
#
# Implementation of methods for the Julia interface to the Spinnaker SDK.
#
#------------------------------------------------------------------------------

to_bool(x::SpinBool) = (x != zero(x))

"""
    SpinnakerCameras.isnull(arg)

yields whether `arg` is a null pointer of a Spinnaker object with a null
handle.

"""
isnull(obj::SpinObject) = isnull(handle(obj))
isnull(ptr::Ptr{T}) where {T} = (ptr == null_pointer(T))

null_pointer(::Type{T}) where {T} = Ptr{T}(0)
null_pointer(x) = null_pointer(typeof(x))

"""
    SpinnakerCameras.handle(obj) -> ptr

yields the handle of Spinnaker object `obj`.  This function is for the
low-level interface, it shall not be used by the end-user.

"""
handle(obj::SpinObject) = getfield(obj, :handle)

_clear_handle!(obj::SpinObject) =
    setfield!(obj, :handle, fieldtype(typeof(obj), :handle)(0))

system(sys::System) = obj
system(obj::SpinObject) = getfield(obj, :system)

"""
    SpinnakerCameras.shortname(obj) -> str

yields the name of Spinnaker object `obj`.  The object type may be specified
instead.

"""
shortname(obj::SpinObject) = shortname(typeof(obj))
shortname(::Type{<:System}) = "object system"
shortname(::Type{<:Interface}) = "interface"
shortname(::Type{<:InterfaceList}) = "interface list"
shortname(::Type{<:CameraList}) = "camera list"
shortname(::Type{<:Camera}) = "camera"
shortname(::Type{<:Image}) = "image"

"""
    SpinnakerCameras.check(obj) -> obj

throws an exception if the handle of object `obj` is null, otherwise returns
the object.

"""
function check(obj::SpinObject)
    isnull(obj) && error("Spinnaker ", shortname(obj), " has been finalized")
    return obj
end

# This version of `_finalize` implements the do-block syntax.  If the handle of
# object `obj` is not null, function `func` is called with the handle value and
# the object handle is set to null.
function _finalize(func::Function, obj::SpinObject)
    ptr = handle(obj)
    if ! isnull(ptr)
        _clear_handle!(obj)
        func(ptr)
    end
    return nothing
end

# Get length/size of some Spinnaker objects.
for (jl_func, type, c_func) in (
    (:length, :InterfaceList, :spinInterfaceListGetSize),
    #(:sizeof, :Image,         :spinImageGetSize),
    (:length, :CameraList,    :spinCameraListGetSize),
    (:length, :NodeMap,       :spinNodeMapGetNumNodes),)
    handle_type = Symbol(type,"Handle")
    @eval begin
        function $jl_func(obj::$type)
            isnull(obj) && return 0
            ref = Ref{Csize_t}()
            @checked_call($c_func, ($handle_type, Ptr{Csize_t}),
                          handle(obj), ref)
            return Int(ref[])
        end
    end
end

#------------------------------------------------------------------------------
# SYSTEM

"""
    sys = SpinnakerCameras.System()

yields an instance `sys` of Spinnaker object system.  The following properties
are implemented:

    sys.cameras        # yields the list of cameras
    sys.interfaces     # yields the list of interfaces
    sys.libraryversion # yields the version number of the SDK library

""" System

_finalize(obj::System) = _finalize(obj) do ptr
    @checked_call(:spinSystemReleaseInstance, (SystemHandle,), ptr)
end

propertynames(::System) = (
    :cameras,
    :interfaces,
    :libraryversion)

getproperty(obj::System, sym::Symbol) = getproperty(obj, Val(sym))

setproperty!(obj::System, sym::Symbol, val) =
    error("members of Spinnaker ", shortname(obj), " are read-only")

getproperty(sys::System, ::Val{:cameras}) = CameraList(sys)
getproperty(sys::System, ::Val{:interfaces}) = InterfaceList(sys)
getproperty(sys::System, ::Val{:libraryversion}) = VersionNumber(sys)

"""
    SpinnakerCameras.LibraryVersion(sys)

yields the version of the Spinnaker library for object system `sys`.

"""
function LibraryVersion(sys::System)
    ref = Ref{LibraryVersion}()
    @checked_call(:spinSystemGetLibraryVersion,
                  (SystemHandle, Ptr{LibraryVersion},),
                  handle(sys), ref)
    return ref[]
end

VersionNumber(sys::System) = VersionNumber(LibraryVersion(sys))
VersionNumber(v::LibraryVersion) =
    VersionNumber(v.major, v.minor, v.type, (), (v.build,))

#------------------------------------------------------------------------------
# LISTS OF INTERFACES

"""
    lst = SpinnakerCameras.InterfaceList(sys)

yields a list of Spinnaker interfaces for the system `sys`.  This is the same
as `sys.interfaces`.

Call `length(lst)` to retrieve the number of interfaces and use syntax `lst[i]`
to get the `i`-th interface.

""" InterfaceList

getindex(lst::InterfaceList, i::Integer) = Interface(lst, i)

empty!(obj::InterfaceList) = begin
    @checked_call(:spinInterfaceListClear, (InterfaceListHandle,), handle(obj))
    return obj
end

_finalize(obj::InterfaceList) = _finalize(obj) do ptr
    err1 = @unchecked_call(:spinInterfaceListClear,
                           (InterfaceListHandle,), ptr)
    err2 = @unchecked_call(:spinInterfaceListDestroy,
                           (InterfaceListHandle,), ptr)
    _check(err1, :spinInterfaceListClear)
    _check(err2, :spinInterfaceListDestroy)
end

# Make interface lists and camera lists iterable.
function iterate(itr::Union{InterfaceList,CameraList},
                 state::NTuple{2,Int} = (1, length(itr)))
    idx, len = state
    if idx ≤ len
        return itr[idx], (idx+1, len)
    else
        return nothing
    end
end

#------------------------------------------------------------------------------
# INTERFACES

"""
    int = SpinnakerCameras.Interface(lst, i)

yields the `i`-th entry of Spinnaker interface list `lst`.  This is the same as
`lst[i]`.

""" Interface

propertynames(::Interface) = (:cameras,)

getproperty(obj::Interface, sym::Symbol) = getproperty(obj, Val(sym))

setproperty!(obj::Interface, sym::Symbol, val) =
    error("members of Spinnaker ", shortname(obj), " are read-only")

getproperty(obj::Interface, ::Val{:cameras}) = CameraList(obj)

_finalize(obj::Interface) = _finalize(obj) do ptr
    @checked_call(:spinInterfaceRelease, (InterfaceHandle,), ptr)
end

#------------------------------------------------------------------------------
# LISTS OF CAMERAS

"""
    lst = SpinnakerCameras.CameraList(sys)
    lst = SpinnakerCameras.CameraList(int)

yield a list of Spinnaker cameras for the system `sys` or for the interface
`int`.   This is the same as `sys.cameras` and `int.cameras` respectively.

Call `length(lst)` to retrieve the number of cameras and use syntax `lst[i]` to
get the `i`-th camera.

""" CameraList

getindex(lst::CameraList, i::Integer) = Camera(lst, i)

empty!(obj::CameraList) = begin
    @checked_call(:spinCameraListClear, (CameraListHandle,), handle(obj))
    return obj
end

_finalize(obj::CameraList) = _finalize(obj) do ptr
    err1 = @unchecked_call(:spinCameraListClear,
                           (CameraListHandle,), ptr)
    err2 = @unchecked_call(:spinCameraListDestroy,
                           (CameraListHandle,), ptr)
    _check(err1, :spinCameraListClear)
    _check(err2, :spinCameraListDestroy)
end

#------------------------------------------------------------------------------
# CAMERAS

"""
    SpinnakerCameras.Camera(lst, i)

yields the `i`-th entry of Spinnaker interface list `lst`.  This is the same
as `lst[i]`.

""" Camera

"""
    SpinnakerCameras.initialize(cam)

initializes Spinnaker camera `cam`.

""" initialize

"""
    SpinnakerCameras.deinitialize(cam)

deinitializes Spinnaker camera `cam`.

""" deinitialize

"""
    SpinnakerCameras.start(cam)

starts acquisition with Spinnaker camera `cam`.

""" start

"""
    SpinnakerCameras.stop(cam)

stops acquisition with Spinnaker camera `cam`.

""" stop

for (jl_func, c_func) in ((:initialize,   :spinCameraInit),
                          (:deinitialize, :spinCameraDeInit),
                          (:start,        :spinCameraBeginAcquisition),
                          (:stop,         :spinCameraEndAcquisition),)
    _jl_func = Symbol("_", jl_func)
    @eval begin
        $jl_func(obj::Camera) = $_jl_func(handle(obj))
        $_jl_func(ptr::CameraHandle) =
            @checked_call($c_func, (CameraHandle,), ptr)
    end
end

"""
    SpinnakerCameras.isinitialized(cam)

yields whether Spinnaker camera `cam` is initialized.

""" isinitialized

"""
    SpinnakerCameras.isstreaming(cam)

yields whether Spinnaker camera `cam` is currently acquiring images.

""" isstreaming

"""
    isvalid(cam)

yields whether Spinnaker camera `cam` is still valid for use.

""" isvalid

for (jl_func, c_func) in ((:isinitialized, :spinCameraIsInitialized),
                          (:isstreaming,   :spinCameraIsStreaming),
                          (:isvalid,       :spinCameraIsValid),)
    _jl_func = Symbol("_", jl_func)
    @eval begin
        $jl_func(obj::Camera) = $_jl_func(handle(obj))
        function $_jl_func(ptr::CameraHandle)
            isnull(ptr) && return false
            ref = Ref{SpinBool}()
            @checked_call($c_func, (CameraHandle, Ptr{SpinBool}), ptr, ref)
            return to_bool(ref[])
        end
    end
end

function _finalize(obj::Camera)
    ptr = handle(obj)
    if _isinitialized(ptr)
        _deinitialize(ptr)
    end
    if !isnull(ptr)
        _clear_handle!(cam)
        @checked_call(:spinCameraRelease, (CameraHandle,), ptr)
    end
    return nothing
end

#------------------------------------------------------------------------------
# NODES

getindex(lst::NodeMap, idx::Integer) = Node(lst, idx)
getindex(lst::NodeMap, str::AbstractString) = Node(lst, str)

"""
    SpinnakerCameras.getvalue(T, node[, verif])

yields the value of a Spinnaker node.  Argument `T` is the type of the result,
`T<:Integer` for an integer-valued node and `T<:AbstractFloat` for a
real-valued node.  Optional argument `verif` is to manually specify whether to
verify the node.

""" getvalue

"""
    SpinnakerCameras.getmin(T, node)

yields the minimum value of a Spinnaker node.  Argument `T` is the type of the
result, `T<:Integer` for an integer-valued node and `T<:AbstractFloat` for a
real-valued node.

""" getmin

"""
    SpinnakerCameras.getmax(T, node)

yields the maximum value of a Spinnaker node.  Argument `T` is the type of the
result, `T<:Integer` for an integer-valued node and `T<:AbstractFloat` for a
real-valued node.

""" getmax

"""
    SpinnakerCameras.getinc(T, node)

yields the increment of an integer Spinnaker node.  Argument `T` is the type of
the result.

""" getinc

for (jl_func, type, c_func) in (
    (:getvalue, Int64,   :spinIntegerGetValue),
    (:getmin,   Int64,   :spinIntegerGetMin),
    (:getmax,   Int64,   :spinIntegerGetMax),
    (:getinc,   Int64,   :spinIntegerGeInc),
    (:getvalue, Cdouble, :spinFloatGetValue),
    (:getmin,   Cdouble, :spinFloatGetMin),
    (:getmax,   Cdouble, :spinFloatGetMAx),)
    @eval function $jl_func(::Type{$type}, node::Node)
        ref = Ref{$type}()
        @checked_call($c_func, (NodeHandle, Ptr{$type}), handle(node), ref)
        return ref[]
    end
    if jl_func === :getvalue
        c_func_ex = Symbol(c_func, "Ex")
        @eval function $jl_func(::Type{$type}, node::Node, verif::Bool)
            ref = Ref{$type}()
            @checked_call($c_func_ex, (NodeHandle, SpinBool, Ptr{$type}),
                          handle(node), verif, ref)
            return ref[]
        end
    end
end

for func in (:getvalue, :getmin, :getmax, :getinc)
    for (T, U) in ((:Integer, :Int64),
                   (:AbstractFloat, :Cdouble))
        if func !== :getinc || T === :Integer
            @eval $func(T::Type{<:$T}, node::Node) =
                convert(T, $func($U, node))
        end
        if func === :getvalue
            @eval $func(T::Type{<:$T}, node::Node, verif::Bool) =
                convert(T, $func($U, node, verif))
        end
    end
end

"""
    SpinnakerCameras.isavailable(nd)

yields whether node `nd` is available.

""" isavailable

"""
    SpinnakerCameras.isimplemented(nd)

yields whether node `nd` is implemented.

""" isimplemented

"""
    SpinnakerCameras.isreadable(nd)

yields whether node `nd` is readable.

""" isreadable

"""
    SpinnakerCameras.iswritable(nd)

yields whether node `nd` is writable.

""" iswritable

for (jl_func, c_func) in ((:isavailable,   :spinNodeIsAvailable),
                          (:isimplemented, :spinNodeIsImplemented),
                          (:isreadable,    :spinNodeIsReadable),
                          (:iswritable,    :spinNodeIsWritable),)
    _jl_func = Symbol("_", jl_func)
    @eval begin
        $jl_func(obj::Node) = $_jl_func(handle(obj))
        function $_jl_func(ptr::NodeHandle)
            isnull(ptr) && return false
            ref = Ref{SpinBool}()
            @checked_call($c_func, (NodeHandle, Ptr{SpinBool}),
                          handle(node), ref)
            return to_bool(ref[])
        end
    end
end

isequal(a::Node, b::Node) = _isequal(ghandle(a), handle(b))
function _isequal(a::NodeHandle, b::NodeHandle)
    (isnull(a) || isnull(b)) && return false
    ref = Ref{SpinBool}()
    @checked_call(:spinNodeIsEqual,
                  (NodeHandle, NodeHandle, Ptr{SpinBool}), a, b, ref)
    return to_bool(ref[])
end

parent(obj::Node) = getfield(obj, :parent)

function _finalize(obj::Node)
    ptr = handle(obj)
    if !isnull(ptr)
        _clear_handle!(obj)
        @checked_call(:spinNodeMapReleaseNode,
                      (NodeMapHandle, NodeHandle),
                      check(parent(node)), # FIXME:
                      ptr)
    end
    return nothing
end
