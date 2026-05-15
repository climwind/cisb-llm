# CISB Analysis Report

**Title**
Fix struct input_event padding on sparc64

**Issue**
Struct padding mismatch on sparc64 causing field misalignment between kernel and user space, and uninitialized padding bytes leaking kernel stack data.

**Tag**
CISB

**Purpose**
Fix struct padding on sparc64 to align with glibc timeval definition and prevent information leaks via uninitialized padding.

---

### Step-by-Step Analysis:
1. **Key Variables/Functionality**: struct input_event definition in include/uapi/linux/input.h and its usage in evdev.c and uinput.c.
2. **Compiler Behavior**: On sparc64, the compiler automatically adds padding after the __usec field for alignment, which was not accounted for in the original struct definition.
3. **Pre/Post Compilation**: The compiler's implicit padding created a layout divergence from the expected glibc timeval definition, causing misaligned data transmission to user space.
4. **Security Implications**: Uninitialized padding bytes in the struct could contain kernel stack data, leading to an information leak when events were copied to user space.
---

1. [yes] Did compiler accept the kernel code and compile it successfully? Code compiled successfully; issue was runtime struct layout mismatch on sparc64, not compilation failure.
2. [yes] Is the commit describing a runtime bug caused by optimization or default compiler behavior? Runtime bug caused by compiler's default padding behavior on sparc64 for alignment after __usec field.
3. [yes] Without that optimization or default behavior, would the problematic difference disappear? Compiler's implicit padding created layout divergence from glibc timeval; without it, struct would match user-space expectations.
4. [yes] Did observable runtime behavior change after compilation? User-space received misaligned data with fields in wrong positions due to layout mismatch.
5. [yes] Does the change have direct or indirect security implications in kernel context? Uninitialized padding bytes could leak kernel stack data to user-space; patch zero-initializes padding.

**CISB Status**
yes

---

## Digest JSON

```json
{
  "function_contexts": [
    {
      "file_path": "include/uapi/linux/input.h",
      "primary_symbol": "struct input_event",
      "changed_symbols": [
        "struct input_event"
      ],
      "why_it_matters": "This is the core data structure for input events. Fixing its layout ensures that user-space applications reading events from /dev/input/event* or uinput get correctly aligned data on sparc64.",
      "code_summary": "Added a __pad field after __usec in the sparc64 branch to match the padding implied by glibc's timeval definition, fixing the struct layout."
    },
    {
      "file_path": "drivers/input/evdev.c",
      "primary_symbol": "static void __pass_event(struct evdev_client *client,",
      "changed_symbols": [
        "static void __pass_event(struct evdev_client *client,"
      ],
      "why_it_matters": "This function copies events into the client buffer. Using a struct initializer instead of individual field assignments prevents leaking uninitialized kernel stack data in the padding bytes.",
      "code_summary": "Replaced individual field assignments with a C99 designated initializer for struct input_event, ensuring all fields including padding are zero-initialized."
    },
    {
      "file_path": "drivers/input/misc/uinput.c",
      "primary_symbol": "static int uinput_dev_event(struct input_dev *dev,",
      "changed_symbols": [
        "static int uinput_dev_event(struct input_dev *dev,"
      ],
      "why_it_matters": "This function constructs input events from user-space writes to /dev/uinput. Using a struct initializer ensures the padding bytes are zeroed, preventing information leaks.",
      "code_summary": "Replaced individual field assignments with a C99 designated initializer for struct input_event, ensuring all fields including padding are zero-initialized."
    }
  ],
  "focused_contexts": [
    {
      "file_path": "include/uapi/linux/input.h",
      "reason": "The struct definition change is the core fix; the padding field is added here.",
      "slice_content": "    3  * Copyright (c) 1999-2002 Vojtech Pavlik\n    4  *\n    5  * This program is free software; you can redistribute it and/or modify it\n    6  * under the terms of the GNU General Public License version 2 as published by\n    7  * the Free Software Foundation.\n    8  */\n    9 #ifndef _UAPI_INPUT_H\n   10 #define _UAPI_INPUT_H\n   11 \n   12 \n   13 #ifndef __KERNEL__\n   14 #include <sys/time.h>\n   15 #include <sys/ioctl.h>\n   16 #include <sys/types.h>\n   17 #include <linux/types.h>\n   18 #endif\n   19 \n   20 #include \"input-event-codes.h\"\n   21 \n   22 /*\n   23  * The event structure itself\n   24  * Note that __USE_TIME_BITS64 is defined by libc based on\n   25  * application's request to use 64 bit time_t.\n   26  */\n   27 \n   28 struct input_event {\n   29 #if (__BITS_PER_LONG != 32 || !defined(__USE_TIME_BITS64)) && !defined(__KERNEL__)\n   30 \tstruct timeval time;\n   31 #define input_event_sec time.tv_sec\n   32 #define input_event_usec time.tv_usec\n   33 #else\n   34 \t__kernel_ulong_t __sec;\n   35 #if defined(__sparc__) && defined(__arch64__)\n   36 \tunsigned int __usec;\n   37 #else\n   38 \t__kernel_ulong_t __usec;\n   39 #endif\n   40 #define input_event_sec  __sec\n   41 #define input_event_usec __usec\n   42 #endif\n   43 \t__u16 type;\n   44 \t__u16 code;\n   45 \t__s32 value;\n   46 };"
    },
    {
      "file_path": "drivers/input/evdev.c",
      "reason": "The struct initializer change prevents kernel stack data leak in the evdev path.",
      "slice_content": "  214 static void __pass_event(struct evdev_client *client,\n  215 \t\t\t const struct input_event *event)\n  216 {\n  217 \tclient->buffer[client->head++] = *event;\n  218 \tclient->head &= client->bufsize - 1;\n  219 \n  220 \tif (unlikely(client->head == client->tail)) {\n  221 \t\t/*\n  222 \t\t * This effectively \"drops\" all unconsumed events, leaving\n  223 \t\t * EV_SYN/SYN_DROPPED plus the newest event in the queue.\n  224 \t\t */\n  225 \t\tclient->tail = (client->head - 2) & (client->bufsize - 1);\n  226 \n  227 \t\tclient->buffer[client->tail].input_event_sec =\n  228 \t\t\t\t\t\tevent->input_event_sec;\n  229 \t\tclient->buffer[client->tail].input_event_usec =\n  230 \t\t\t\t\t\tevent->input_event_usec;\n  231 \t\tclient->buffer[client->tail].type = EV_SYN;\n  232 \t\tclient->buffer[client->tail].code = SYN_DROPPED;\n  233 \t\tclient->buffer[client->tail].value = 0;\n  234 \n  235 \t\tclient->packet_head = client->tail;\n  236 \t}\n  237 \n  238 \tif (event->type == EV_SYN && event->code == SYN_REPORT) {\n  239 \t\tclient->packet_head = client->head;\n  240 \t\tkill_fasync(&client->fasync, SIGIO, POLL_IN);\n  241 \t}\n  242 }"
    },
    {
      "file_path": "drivers/input/misc/uinput.c",
      "reason": "The struct initializer change prevents kernel stack data leak in the uinput path.",
      "slice_content": "   64 \tunsigned int\t\tff_effects_max;\n   65 \n   66 \tstruct uinput_request\t*requests[UINPUT_NUM_REQUESTS];\n   67 \twait_queue_head_t\trequests_waitq;\n   68 \tspinlock_t\t\trequests_lock;\n   69 };\n   70 \n   71 static int uinput_dev_event(struct input_dev *dev,\n   72 \t\t\t    unsigned int type, unsigned int code, int value)\n   73 {\n   74 \tstruct uinput_device\t*udev = input_get_drvdata(dev);\n   75 \tstruct timespec64\tts;\n   76 \n   77 \tudev->buff[udev->head].type = type;\n   78 \tudev->buff[udev->head].code = code;\n   79 \tudev->buff[udev->head].value = value;\n   80 \tktime_get_ts64(&ts);\n   81 \tudev->buff[udev->head].input_event_sec = ts.tv_sec;\n   82 \tudev->buff[udev->head].input_event_usec = ts.tv_nsec / NSEC_PER_USEC;\n   83 \tudev->head = (udev->head + 1) % UINPUT_BUFFER_SIZE;\n   84 \n   85 \twake_up_interruptible(&udev->waitq);\n   86 \n   87 \treturn 0;\n   88 }\n   89 \n   90 /* Atomically allocate an ID for the given request. Returns 0 on success. */\n   91 static bool uinput_request_alloc_id(struct uinput_device *udev,\n   92 \t\t\t\t    struct uinput_request *request)\n   93 {\n   94 \tunsigned int id;\n   95 \tbool reserved = false;\n   96 "
    }
  ]
}
```
