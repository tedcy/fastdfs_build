#include <stdbool.h>
#include <time.h>
#include <stdint.h>

#define IP_ADDRESS_SIZE         16

typedef struct {
        time_t create_timestamp;
        int crc32;
        int source_id;   //source storage id
        int64_t file_size;
        char source_ip_addr[IP_ADDRESS_SIZE];  //source storage ip address
} FDFSFileInfo;

int fdfs_get_file_info_ex(const char *group_name, const char *remote_filename, \
        const bool get_from_server, FDFSFileInfo *pFileInfo);
