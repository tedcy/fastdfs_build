#include <stdlib.h>
#include <stdio.h>

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

void check_args(int argc,char** argv)
{
	if(argc == 1) {
		printf("helper\n");
		printf("./fastdfs_get_file_info <file_id_without_group_name>\n");
		printf("such as ./fastdfs_get_file_info M00/11/33/rBADEVSxBzuAWW5oAABXOePRiks30..jpg\n");
		exit(1);
	}
}

int main(int argc,char** argv)
{
	check_args(argc,argv);
	FDFSFileInfo file_info;
	fdfs_get_file_info_ex("group1",argv[1],true,&file_info);
	printf("file create_timestamp: %ld\n",file_info.create_timestamp);
	printf("file crc32: %d\n",file_info.crc32);
	printf("file source_id: %d\n",file_info.source_id);
	printf("file file_size: %ld\n",file_info.file_size);
	printf("file source_ip_addr: %s\n",file_info.source_ip_addr);
	return 0;
}
