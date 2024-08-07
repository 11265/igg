#ifndef PROCESS_UTILS_H
#define PROCESS_UTILS_H

#include <sys/types.h>
#include <sys/sysctl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

// 定义 kinfo_proc 结构体别名
typedef struct kinfo_proc kinfo_proc;

// 根据进程名获取PID的函数声明
pid_t get_pid_by_name(const char *process_name);

// 进程信息结构体
typedef struct
{
    int pid;                // 进程ID
    const char *processname; // 进程名
} ProcessInfo;

// 模块信息结构体
typedef struct
{
    uintptr_t base;    // 模块基址
    int size;          // 模块大小
    bool is_64bit;     // 是否为64位模块
    char *modulename;  // 模块名
} ModuleInfo;

#ifdef __cplusplus
extern "C" {
#endif


// 获取当前进程的PID
pid_t get_pid_native();

// 读取指定进程的内存
ssize_t read_memory_native(int pid, mach_vm_address_t address, mach_vm_size_t size, unsigned char *buffer);

// 写入指定进程的内存
ssize_t write_memory_native(int pid, mach_vm_address_t address, mach_vm_size_t size, unsigned char *buffer);

// 枚举指定进程的内存区域
void enumerate_regions_to_buffer(pid_t pid, char *buffer, size_t buffer_size);

// 枚举系统中的所有进程
ProcessInfo *enumprocess_native(size_t *count);

// 暂停指定进程
bool suspend_process(pid_t pid);

// 恢复指定进程
bool resume_process(pid_t pid);

// 枚举指定进程的所有模块
ModuleInfo *enummodule_native(pid_t pid, size_t *count);

#ifdef __cplusplus
}
#endif

#endif // PROCESS_UTILS_H