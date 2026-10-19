#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdint.h>
#include <fcntl.h>
#include <pthread.h>
#include <time.h>
#include <string.h>

#define FIFO_DEPTH 64
#define PMU_METRIC_COUNT 19
#define PMU_DATA_WIDTH 32
#define ROUTERS_COUNT 9
#define COMMAND_WIDTH 128

#define PMU_DATA_BYTES     (PMU_DATA_WIDTH/8)
#define PMU_TOTAL_BYTES    (PMU_DATA_BYTES*PMU_METRIC_COUNT)
#define COMMAND_BYTES      (COMMAND_WIDTH/8)
#define PMU_WIDTH_RATIO    ((PMU_METRIC_COUNT*PMU_DATA_WIDTH / COMMAND_WIDTH) + (PMU_METRIC_COUNT*PMU_DATA_WIDTH % COMMAND_WIDTH != 0))
#define PMU_TRANSFER_BYTES (PMU_WIDTH_RATIO*COMMAND_BYTES)

#define ROUTERS_COUNT_WIDTH 4
#define AXI_DATA_WIDTH 32
#define AXI_ID_W_WIDTH 5
#define AXI_ID_R_WIDTH 5
#define AXI_ADDR_WIDTH 12 
#define AXI_MAX_ID_WIDTH ((AXI_ID_W_WIDTH > AXI_ID_R_WIDTH) ? AXI_ID_W_WIDTH : AXI_ID_R_WIDTH)

#define ROUTERS_COUNT_BYTES (ROUTERS_COUNT_WIDTH / 8 + (ROUTERS_COUNT_WIDTH % 8 != 0))
#define AXI_DATA_BYTES      (AXI_DATA_WIDTH      / 8 + (AXI_DATA_WIDTH      % 8 != 0))
#define AXI_MAX_ID_BYTES    (AXI_MAX_ID_WIDTH    / 8 + (AXI_MAX_ID_WIDTH    % 8 != 0))
#define AXI_ADDR_BYTES      (AXI_ADDR_WIDTH      / 8 + (AXI_ADDR_WIDTH      % 8 != 0))
#define AXI_WSTRB_BYTES     (AXI_DATA_BYTES      / 8 + (AXI_DATA_BYTES      % 8 != 0))

int main (int argc, char **argv) {
    if (argc < 2) {
        return -1;
    }

    char *bdf = malloc(sizeof(strlen(argv[1])+1));
    if (!bdf) {
        printf("Argv 1 alloc error\n");
        return -1;
    }
    if (!strcpy(bdf, argv[1])) {
        printf("Argv 1 strcpy error\n");
        return -1;
    }

    int size;
    char *filepath;

    size = asprintf(&filepath, "/dev/hdlnocgen_%s_0", bdf);
    if (size < 0) {
        printf("Asprintf error\n");
        return size;
    }
    printf("Target file %s\n", filepath);

    int dma_fd = open(filepath, O_RDWR);
    free(filepath);
    if (dma_fd < 0) {
        printf("Device or channel does not exist\n");
        return dma_fd;
    }


    size = asprintf(&filepath, "/dev/hdlnocgen_%s_dma_csr", bdf);
    if (size < 0) {
        printf("Asprintf error\n");
        return size;
    }
    printf("Target file %s\n", filepath);

    int csr_fd = open(filepath, O_RDWR);
    free(filepath);
    if (csr_fd < 0) {
        printf("Device or channel does not exist\n");
        return csr_fd;
    }


    size = asprintf(&filepath, "/dev/hdlnocgen_%s_env_csr", bdf);
    if (size < 0) {
        printf("Asprintf error\n");
        return size;
    }
    printf("Target file %s\n", filepath);

    int usr_csr_fd = open(filepath, O_RDWR);
    free(filepath);
    if (usr_csr_fd < 0) {
        printf("Device or channel does not exist\n");
        return usr_csr_fd;
    }


    size = asprintf(&filepath, "/dev/hdlnocgen_%s_user_irq", bdf);
    if (size < 0) {
        printf("Asprintf error\n");
        return size;
    }
    printf("Target file %s\n", filepath);

    int user_irq_fd = open(filepath, O_RDWR);
    free(filepath);
    if (user_irq_fd < 0) {
        printf("Device or channel does not exist\n");
        return user_irq_fd;
    }

    printf("All files opened\n");

    uint8_t user_irq = 0;
    pwrite(user_irq_fd, &user_irq, sizeof(user_irq), (off_t)0x0);
    
    uint32_t wdata;
    uint32_t rdata;

    wdata = 0x0;
    pwrite(csr_fd, &wdata, 4, (off_t)0xC);
    printf("DMA controller is reset\n");

    wdata = 0x1;
    pwrite(usr_csr_fd, &wdata, 4, (off_t)0x0);
    do {
        pread(usr_csr_fd, &rdata, 4, (off_t)0x0);
    } while ((rdata & 0x3) >> 1 != 1);
    printf("%x\n", rdata);

    wdata = 0x0;
    pwrite(usr_csr_fd, &wdata, 4, (off_t)0x0);
    do {
        pread(usr_csr_fd, &rdata, 4, (off_t)0x0);
    } while ((rdata & 0x3) >> 1 != 0);
    printf("%x\n", rdata);

    wdata = 0x1;
    pwrite(usr_csr_fd, &wdata, 4, (off_t)0x0);
    do {
        pread(usr_csr_fd, &rdata, 4, (off_t)0x0);
    } while ((rdata & 0x3) >> 1 != 1);
    printf("%x\n", rdata);

    wdata = 0xD9;
    uint32_t core_enable = 0xD9;
    pwrite(usr_csr_fd, &wdata, 4, (off_t)0x10);

    pread(usr_csr_fd, &rdata, 4, (off_t)0x10);
    printf("%x\n", rdata);

    pread(usr_csr_fd, &rdata, 4, (off_t)0x30);
    printf("%x\n", rdata);

    pread(usr_csr_fd, &rdata, 4, (off_t)0x50);
    printf("%x\n", rdata);

    uint8_t task_array[FIFO_DEPTH*5 * COMMAND_BYTES];

    uint64_t byte_counter = 0;
    int write_count = 32;
    int axlen_arg = 3;
    int queue_depth = 34;

    printf("%d, %d, %d, %d, %d\n", ROUTERS_COUNT_BYTES, AXI_DATA_BYTES, AXI_MAX_ID_BYTES, AXI_ADDR_BYTES, AXI_WSTRB_BYTES);    

    for (uint64_t i = 0; i < ROUTERS_COUNT; i++) {
        if (!((core_enable >> i) % 2)) {
            continue;
        }

        for (int j = 0; j < FIFO_DEPTH; j++) {
            uint64_t router_id = i;
            uint8_t resp_wait = (j < write_count) ?
                                ((((j+1) % queue_depth) == 0) ? 1 : 0) :
                                ((((j-write_count+1) % queue_depth) == 0) ? 1 : 0);
            uint64_t axi_id = rand() % ROUTERS_COUNT + 1;
            uint8_t write = (j < write_count) ? 1 : 0;
            uint64_t address = 0;
            uint8_t axlen = rand() % 256;

            for (int k = 0; k < AXI_WSTRB_BYTES; k++) {
                task_array[byte_counter] = rand() % 256;
                byte_counter++;
            }
            for (int k = 0; k < AXI_DATA_BYTES; k++) {
                task_array[byte_counter] = rand() % 256;
                byte_counter++;
            }
            task_array[byte_counter] = axlen;
            byte_counter++;
            for (int k = 0; k < AXI_ADDR_BYTES; k++) {
                task_array[byte_counter] = (uint8_t)address;
                address = address >> 8;
                byte_counter++;
            }
            task_array[byte_counter] = write;
            byte_counter++;
            for (int k = 0; k < AXI_MAX_ID_BYTES; k++) {
                task_array[byte_counter] = (uint8_t)axi_id;
                axi_id = axi_id >> 8;
                byte_counter++;
            }
            task_array[byte_counter] = resp_wait;
            byte_counter++;
            for (int k = 0; k < ROUTERS_COUNT_BYTES; k++) {
                task_array[byte_counter] = (uint8_t)router_id;
                router_id = router_id >> 8;
                byte_counter++;
            }

            while (byte_counter % COMMAND_BYTES != 0) {
                task_array[byte_counter] = 0x0;
                byte_counter++;
            }
        }
    }

    pread(user_irq_fd, &user_irq, sizeof(user_irq), (off_t)0x0);
    printf("User IRQ %u\n", user_irq);

    write(dma_fd, task_array, sizeof(task_array));


    wdata = 0x5;
    pwrite(usr_csr_fd, &wdata, 4, (off_t)0x0);
    pread(usr_csr_fd, &rdata, 4, (off_t)0x30);
    printf("%x\n", rdata);

    int deadlock_counter = 0;
    for (deadlock_counter; deadlock_counter < 1000000; deadlock_counter++) {
        pread(user_irq_fd, &user_irq, sizeof(user_irq), (off_t)0x0);
        if (user_irq == 1) {
            break;
        }
    }
    if (deadlock_counter == 1000000) {
        printf("DEADLOCK!\n");
    }
    else {
        printf("Interrupt received!\n");
    }
    user_irq = 0;
    pwrite(user_irq_fd, &user_irq, sizeof(user_irq), (off_t)0x0);
    pread(usr_csr_fd, &rdata, 4, (off_t)0x30);
    printf("%x\n", rdata);

    uint8_t pmu[ROUTERS_COUNT * PMU_TRANSFER_BYTES];

    wdata = 0x9;
    pwrite(usr_csr_fd, &wdata, 4, (off_t)0x0);
    read(dma_fd, pmu, sizeof(pmu));

    for (int i = 0; i < ROUTERS_COUNT*PMU_TRANSFER_BYTES; i += PMU_TRANSFER_BYTES) {
        for (int j = 0; j < PMU_TOTAL_BYTES; j += PMU_DATA_BYTES) {
            uint32_t metric = 0;
            for (int k = 0; k < PMU_DATA_BYTES; k++) {
                metric += (pmu[i+j+k] << (k*8));
            }
            printf("%08x", metric);
            if (j+PMU_DATA_BYTES < PMU_TOTAL_BYTES) {
                printf(",");
            }
        }
        printf("\n");
    }

    pread(usr_csr_fd, &rdata, 4, (off_t)0x30);
    printf("%x\n", rdata);

    pread(usr_csr_fd, &rdata, 4, (off_t)0x50);
    printf("%x\n", rdata);

    close(dma_fd);
    close(csr_fd);
    close(usr_csr_fd);
    close(user_irq_fd);
}
