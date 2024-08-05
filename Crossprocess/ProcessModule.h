#ifndef PROCESS_UTILS_H
#define PROCESS_UTILS_H

#include <sys/types.h>
#include <sys/sysctl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

typedef struct kinfo_proc kinfo_proc;

// 获取进程列表
//static int get_proc_list(kinfo_proc **procList, size_t *procCount);

// 根据进程名获取PID
pid_t get_pid_by_name(const char *process_name);

#endif // PROCESS_UTILS_H