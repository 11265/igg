#include <Foundation/Foundation.h>
#include <dlfcn.h>
#include <errno.h>
#include <mach-o/dyld_images.h>
#include <mach-o/fat.h>
#include <mach-o/loader.h>
#include <mach/mach.h>
#include <mach/task.h>
#include <mach/vm_map.h>
#include <mach/vm_region.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/queue.h>
#include <sys/sysctl.h>
#include <iostream>
#include <string>
#include <vector>
#include <stdbool.h>  // 添加这行
#include <strings.h>
#include <cctype>  // 包含 std::tolower

// 获取进程列表
extern "C" int get_proc_list(kinfo_proc **procList, size_t *procCount) 
{
    int err;
    kinfo_proc *result = NULL;
    bool done = false;
    static const int name[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    size_t length;

    *procCount = 0;

    do {
        length = 0;
        err = sysctl((int *)name, (sizeof(name) / sizeof(*name)) - 1, NULL, &length, NULL, 0);
        if (err == -1) {
            err = errno;
            break;
        }

        result = (kinfo_proc *)malloc(length);
        if (result == NULL) {
            err = ENOMEM;
            break;
        }

        err = sysctl((int *)name, (sizeof(name) / sizeof(*name)) - 1, result, &length, NULL, 0);
        if (err == -1) {
            err = errno;
            free(result);
            result = NULL;
        } else {
            done = true;
        }
    } while (err == 0 && !done);

    if (err != 0 && result != NULL) {
        free(result);
        result = NULL;
    }

    if (err == 0) {
        *procList = result;
        *procCount = length / sizeof(kinfo_proc);
    }

    return err;
}

// 根据进程名获取PID
extern "C"  pid_t get_pid_by_name(const char *process_name) 
{
    kinfo_proc *procList = NULL;
    size_t procCount = 0;
    int err = get_proc_list(&procList, &procCount);
    
    if (err != 0) {
        fprintf(stderr, "无法获取进程列表: %d\n", err);
        return -1;
    }

    pid_t target_pid = -1;
    for (size_t i = 0; i < procCount; i++) {
        if (strcmp(procList[i].kp_proc.p_comm, process_name) == 0) {
            target_pid = procList[i].kp_proc.p_pid;
            break;
        }
    }

    free(procList);
    return target_pid;
}