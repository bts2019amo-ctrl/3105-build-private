import Darwin
import Foundation

/// Defensive runtime checks. These checks are signals, not a replacement for
/// server-side authorization or code-signing protection.
enum SecurityGuard {
    static var isDebuggerAttached: Bool {
        var processInfo = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]

        let result = mib.withUnsafeMutableBufferPointer { pointer in
            sysctl(pointer.baseAddress, u_int(pointer.count), &processInfo, &size, nil, 0)
        }
        guard result == 0 else { return false }
        return (processInfo.kp_proc.p_flag & P_TRACED) != 0
    }

    static var hasInjectedDynamicLibrary: Bool {
        guard let value = getenv("DYLD_INSERT_LIBRARIES") else { return false }
        return String(cString: value).isEmpty == false
    }

    static var isCompromised: Bool {
#if DEBUG
        return false
#else
        return isDebuggerAttached || hasInjectedDynamicLibrary
#endif
    }
}
