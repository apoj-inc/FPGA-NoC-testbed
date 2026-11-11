#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdint.h>
#include <fcntl.h>
#include <pthread.h>
#include <time.h>
#include <string.h>
#include <math.h>
#include <sys/time.h>

#define ITERATION_COUNT (uint64_t)(4096)

int ROUTERS_COUNT;
int FIFO_DEPTH;
int PMU_METRIC_COUNT;
int PMU_DATA_WIDTH;
int COMMAND_WIDTH;
int PMU_DATA_BYTES;
int PMU_TOTAL_BYTES;
int COMMAND_BYTES;
int PMU_WIDTH_RATIO;
int PMU_TRANSFER_BYTES;
int ROUTERS_COUNT_WIDTH;
int AXI_DATA_WIDTH;
int AXI_ID_W_WIDTH;
int AXI_ID_R_WIDTH;
int AXI_ADDR_WIDTH;
int AXI_MAX_ID_WIDTH;
int ROUTERS_COUNT_BYTES;
int AXI_DATA_BYTES;
int AXI_MAX_ID_BYTES;
int AXI_ADDR_BYTES;
int AXI_WSTRB_BYTES;

uint32_t randomize_core_enable(int active_core_count) {
    uint32_t core_enable = 0;
    uint8_t core_array[ROUTERS_COUNT];
    uint8_t index_array[ROUTERS_COUNT];
    for (int i = 0; i < ROUTERS_COUNT; i++) {
        core_array[i] = 0;
        index_array[i] = i;
    }

    int chosen;
    for (int i = 0; i < active_core_count; i++) {
        chosen = rand() % (ROUTERS_COUNT-i);
        core_array[index_array[chosen]] = 1;
        for (int j = chosen; j < ROUTERS_COUNT-i-1; j++) {
            index_array[j] = index_array[j+1];
        }
    }

    for (int i = 0; i < ROUTERS_COUNT; i++) {
        core_enable += core_array[i] * (1 << i);
    }

    return core_enable;
}

void generate_tasks(uint8_t *task_array, uint32_t core_enable, int write_count, int axlen_arg, int queue_depth) {

    uint64_t byte_counter = 0;
    
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
            uint8_t axlen = axlen_arg;

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
                byte_counter++;
            }
        }
    }
}

void reset_testbed(int usr_csr_fd) {
    uint32_t wdata, rdata;

    wdata = 0x1;
    pwrite(usr_csr_fd, &wdata, 4, (off_t)0x0);
    do {
        pread(usr_csr_fd, &rdata, 4, (off_t)0x0);
    } while ((rdata & 0x3) >> 1 != 1);

    wdata = 0x0;
    pwrite(usr_csr_fd, &wdata, 4, (off_t)0x0);
    do {
        pread(usr_csr_fd, &rdata, 4, (off_t)0x0);
    } while ((rdata & 0x3) >> 1 != 0);

    wdata = 0x1;
    pwrite(usr_csr_fd, &wdata, 4, (off_t)0x0);
    do {
        pread(usr_csr_fd, &rdata, 4, (off_t)0x0);
    } while ((rdata & 0x3) >> 1 != 1);
}


int main (int argc, char **argv) {
    struct timeval time_of_day;
    gettimeofday(&time_of_day, NULL);

    srand((uint64_t)(time_of_day.tv_sec + time_of_day.tv_usec));

    if (argc < 4) {
        return -1;
    }

    ROUTERS_COUNT = atoi(argv[2]);

    FIFO_DEPTH = 64;
    PMU_METRIC_COUNT = 19;
    PMU_DATA_WIDTH = 32;
    COMMAND_WIDTH = 128;
    PMU_DATA_BYTES     = (PMU_DATA_WIDTH/8);
    PMU_TOTAL_BYTES    = (PMU_DATA_BYTES*PMU_METRIC_COUNT);
    COMMAND_BYTES      = (COMMAND_WIDTH/8);
    PMU_WIDTH_RATIO    = ((PMU_METRIC_COUNT*PMU_DATA_WIDTH / COMMAND_WIDTH) + (PMU_METRIC_COUNT*PMU_DATA_WIDTH % COMMAND_WIDTH != 0));
    PMU_TRANSFER_BYTES = (PMU_WIDTH_RATIO*COMMAND_BYTES);
    ROUTERS_COUNT_WIDTH = ceil(log((double)ROUTERS_COUNT) / log(2.0));
    AXI_DATA_WIDTH = 32;
    AXI_ID_W_WIDTH = 5;
    AXI_ID_R_WIDTH = 5;
    AXI_ADDR_WIDTH = 12 ;
    AXI_MAX_ID_WIDTH = ((AXI_ID_W_WIDTH > AXI_ID_R_WIDTH) ? AXI_ID_W_WIDTH : AXI_ID_R_WIDTH);
    ROUTERS_COUNT_BYTES = (ROUTERS_COUNT_WIDTH / 8 + (ROUTERS_COUNT_WIDTH % 8 != 0));
    AXI_DATA_BYTES      = (AXI_DATA_WIDTH      / 8 + (AXI_DATA_WIDTH      % 8 != 0));
    AXI_MAX_ID_BYTES    = (AXI_MAX_ID_WIDTH    / 8 + (AXI_MAX_ID_WIDTH    % 8 != 0));
    AXI_ADDR_BYTES      = (AXI_ADDR_WIDTH      / 8 + (AXI_ADDR_WIDTH      % 8 != 0));
    AXI_WSTRB_BYTES     = (AXI_DATA_BYTES      / 8 + (AXI_DATA_BYTES      % 8 != 0));

    int size;
    char *filepath;

    size = asprintf(&filepath, "/dev/hdlnocgen_%s_0", argv[1]);
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


    size = asprintf(&filepath, "/dev/hdlnocgen_%s_dma_csr", argv[1]);
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


    size = asprintf(&filepath, "/dev/hdlnocgen_%s_env_csr", argv[1]);
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


    size = asprintf(&filepath, "/dev/hdlnocgen_%s_user_irq", argv[1]);
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
    printf("All DMA files opened\n");


    size = asprintf(&filepath, "%s_%s.csv", argv[1], argv[3]);
    if (!size) {
        printf("Failed to generate filepath\n");
        perror("Reason:");
        return size;
    }

    FILE *file;
    file = fopen(filepath, "w");
    if (!file) {
        printf("Failed to open/create file %s\n", filepath);
        perror("Reason:");
        return -1;
    }
    printf("CSV files opened\n");

    const char *table_header[] = {
        "active_core_count",
        "write_count",
        "axlen",
        "queue_depth",
        "router_index",
        "read_idle",
        "read_outstanding",
        "read_ar_stall",
        "read_ar_handshake",
        "read_rvalid_stall",
        "read_rready_stall",
        "read_r_handshake",
        "write_idle",
        "write_outstanding",
        "write_responding",
        "write_aw_stall",
        "write_aw_handshake",
        "write_wvalid_stall",
        "write_wready_stall",
        "write_w_handshake",
        "write_bvalid_stall",
        "write_bready_stall",
        "write_b_handshake",
        "clock_counter"
    };

    for (int i = 0; i < sizeof(table_header)/sizeof(table_header[0]); i++) {
        fprintf(file, "%s", table_header[i]);
        if (i+1 < sizeof(table_header)/sizeof(table_header[0])) {
            fprintf(file, ",");
        }
    }
    fprintf(file, "\n");

    uint8_t user_irq = 0;
    pwrite(user_irq_fd, &user_irq, sizeof(user_irq), (off_t)0x0);
    
    uint32_t wdata;
    uint32_t rdata;

    wdata = 0x0;
    pwrite(csr_fd, &wdata, 4, (off_t)0xC);
    printf("DMA controller is reset\n");

    int queue_depth = 34;
    uint32_t active_core_count = 0;
    uint32_t active_core_count_index = 0;

    while (active_core_count < ROUTERS_COUNT) {
        active_core_count = 1 << active_core_count_index;
        active_core_count = (active_core_count >= ROUTERS_COUNT) ? ROUTERS_COUNT : active_core_count;
        active_core_count_index++;
        printf("Active core count: %d\n", active_core_count);

        uint8_t tasks[FIFO_DEPTH*active_core_count * COMMAND_BYTES];
        uint8_t pmu[ROUTERS_COUNT * PMU_TRANSFER_BYTES];

        for (int write_count = 1; write_count < FIFO_DEPTH; write_count += 2) {
            printf("Write count: %d\n", write_count);
            for (int axlen = 1; axlen < 8; axlen += 2) {
                reset_testbed(usr_csr_fd);
                printf("Testbed reset. Axlen: %d\n", axlen);

                for (int iter = 0; iter < ITERATION_COUNT; iter++) {
                    wdata = randomize_core_enable(active_core_count);
                    pwrite(usr_csr_fd, &wdata, 4, (off_t)0x10);

                    uint32_t core_enable = wdata;
                    generate_tasks(tasks, core_enable, write_count, axlen, queue_depth);
                    write(dma_fd, tasks, sizeof(tasks)); // uploads testing data

                    wdata = 0x5;
                    pwrite(usr_csr_fd, &wdata, 4, (off_t)0x0); // starts testing

                    int deadlock_counter = 0;
                    for (deadlock_counter; deadlock_counter < 10000; deadlock_counter++) {
                        pread(user_irq_fd, &user_irq, sizeof(user_irq), (off_t)0x0);
                        if (user_irq == 1) {
                            break;
                        }
                    }
                    user_irq = 0;
                    pwrite(user_irq_fd, &user_irq, sizeof(user_irq), (off_t)0x0);
                    if (deadlock_counter == 10000) {
                        printf("DEADLOCK: %d,%d,%d,%d\n", active_core_count, write_count, axlen, queue_depth);
                        break;
                    }
                }
                wdata = 0x9;
                pwrite(usr_csr_fd, &wdata, 4, (off_t)0x0); // Prepare PMU data

                read(dma_fd, pmu, sizeof(pmu)); // Download PMU data

                for (int i = 0; i < ROUTERS_COUNT*PMU_TRANSFER_BYTES; i += PMU_TRANSFER_BYTES) {
                    fprintf(file, "%d,%d,%d,%d,%d,", active_core_count, write_count, axlen, queue_depth, i/PMU_TRANSFER_BYTES);
                    for (int j = 0; j < PMU_TOTAL_BYTES; j += PMU_DATA_BYTES) {
                        uint32_t metric = 0;
                        for (int k = 0; k < PMU_DATA_BYTES; k++) {
                            metric += (pmu[i+j+k] << (k*8));
                        }
                        fprintf(file, "%u", metric);
                        if (j+PMU_DATA_BYTES < PMU_TOTAL_BYTES) {
                            fprintf(file, ",");
                        }
                    }
                    fprintf(file, "\n");
                }
            }
        }
    }
    printf("Finished!\n");

    close(dma_fd);
    close(csr_fd);
    close(usr_csr_fd);
    close(user_irq_fd);
}
