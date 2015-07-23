#include <ngx_config.h>
#include <ngx_core.h>
#include <ngx_http.h>

#include <string.h>
#include <error.h>

typedef struct {
    ngx_flag_t                   lookup_cache;
    ngx_str_t                    group_name;
} ngx_http_image_cache_conf_t;

static void *
ngx_http_image_cache_create_conf(ngx_conf_t *cf) ;
static char *
ngx_http_image_cache_merge_conf(ngx_conf_t *cf, void *parent, void *child);
static ngx_int_t
ngx_http_image_cache_init(ngx_conf_t *cf);
static ngx_int_t ngx_http_image_cache_handler(ngx_http_request_t *r);

static ngx_command_t ngx_http_image_cache_commands[] = {

    {   ngx_string("image_cache_lookup_cache"),
        NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_FLAG,
        ngx_conf_set_flag_slot,
        NGX_HTTP_LOC_CONF_OFFSET,
        offsetof(ngx_http_image_cache_conf_t, lookup_cache),
        NULL 
    },

    { ngx_string("image_cache_group_name"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_FLAG,
      ngx_conf_set_str_slot,
      NGX_HTTP_LOC_CONF_OFFSET,
      offsetof(ngx_http_image_cache_conf_t, group_name),
      NULL },
    
    ngx_null_command
};

static ngx_http_module_t ngx_http_image_cache_module_ctx = {
    NULL,
    ngx_http_image_cache_init,

    NULL,
    NULL,

    NULL,
    NULL,

    ngx_http_image_cache_create_conf,
    ngx_http_image_cache_merge_conf
};

ngx_module_t ngx_http_image_cache_module = {
    NGX_MODULE_V1,
    &ngx_http_image_cache_module_ctx,
    ngx_http_image_cache_commands,
    NGX_HTTP_MODULE,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NGX_MODULE_V1_PADDING
};

static ngx_int_t
ngx_http_lookup_and_send_cache_file(ngx_http_request_t *r, ngx_chain_t *out)
{
    u_char buf[128];
    u_char file_name[128] = "/data/imagecache/";
    ngx_buf_t *b;
    ngx_pool_cleanup_t *cln;
    size_t name_len;
    u_char *uri_file_name;
    u_char *group_name;
    
    memset(buf,0,128);
    name_len = r->uri_end - r->uri_start;
    memcpy(buf,r->uri_start,name_len);
    uri_file_name = buf + 12;
    group_name = buf + 1;

    ngx_http_image_cache_conf_t  *conf;
    conf = ngx_http_get_module_loc_conf(r, ngx_http_image_cache_module);

    strncat((char*)file_name,(char *)uri_file_name,128);
	
    if(memcmp(conf->group_name.data, group_name, conf->group_name.len) == 0 && \
            access((char *)file_name,F_OK) == 0) {

        b = ngx_palloc(r->pool, sizeof(ngx_buf_t));
        ngx_memzero(b,sizeof(ngx_buf_t));
        b->in_file = 1;
        b->file = ngx_palloc(r->pool, sizeof(ngx_file_t));
        ngx_memzero(b->file,sizeof(ngx_file_t));
        b->file->fd = ngx_open_file(file_name,NGX_FILE_RDONLY|NGX_FILE_NONBLOCK, NGX_FILE_OPEN, 0);

        b->file->log = r->connection->log;
    
        if(b->file->fd <= 0){
            return NGX_HTTP_NOT_FOUND;
        }

        if(ngx_file_info(file_name,&b->file->info) == NGX_FILE_ERROR){
            ngx_http_finalize_request(r,NGX_HTTP_INTERNAL_SERVER_ERROR);
        }

        if(b->file->info.st_size < 128)
            return NGX_HTTP_NOT_FOUND;
        //r->connection->buffered &= ~NGX_HTTP_IMAGE_BUFFERED;
        r->headers_out.content_length_n = b->file->info.st_size;
        if (r->headers_out.content_length) {
            r->headers_out.content_length->hash = 0;
        }

        r->headers_out.content_length = NULL;

        b->file_pos = 0;
        b->file_last = b->file->info.st_size;
        b->last_buf = 1;

        out->buf = b;
        out->next = NULL;
    
        cln = ngx_pool_cleanup_add(r->pool, sizeof(ngx_pool_cleanup_file_t));
        if(cln == NULL){
            ngx_http_finalize_request(r,NGX_ERROR);
        }
        cln->handler = ngx_pool_cleanup_file;
        ngx_pool_cleanup_file_t *clnf = cln->data;

        clnf->fd = b->file->fd;
        clnf->log = r->pool->log;

        return NGX_OK; 
    }

    return NGX_HTTP_NOT_FOUND;
}

static ngx_int_t
ngx_http_image_cache_handler(ngx_http_request_t *r)
{
    ngx_chain_t                    out;
    ngx_int_t                     status;

    if(!(r->method & (NGX_HTTP_GET|NGX_HTTP_HEAD))){
        return NGX_HTTP_NOT_ALLOWED;
    }

    ngx_int_t rc = ngx_http_discard_request_body(r);
    if(rc != NGX_OK){
        return rc;
    }

    ngx_http_image_cache_conf_t  *conf;
    conf = ngx_http_get_module_loc_conf(r, ngx_http_image_cache_module);

    if(!(conf->lookup_cache)){
        return NGX_DECLINED;
    }

    status = ngx_http_lookup_and_send_cache_file(r, &out);

    if(status == NGX_OK){
        ngx_str_set(&r->headers_out.content_type, "text/plain");
        r->headers_out.status = NGX_HTTP_OK;
    
        rc = ngx_http_send_header(r);
        if(rc == NGX_ERROR || rc > NGX_OK || r->header_only){
            return rc;
        }
        ngx_http_output_filter(r,&out);
        return NGX_OK;
    }

    return NGX_DECLINED;
}

static void *
ngx_http_image_cache_create_conf(ngx_conf_t *cf) 
{
    ngx_http_image_cache_conf_t  *conf;

    conf = ngx_pcalloc(cf->pool, sizeof(ngx_http_image_cache_conf_t));
    if (conf == NULL) {
        return NULL;
    }    

    conf->lookup_cache = NGX_CONF_UNSET;
    ngx_str_null(&conf->group_name);

    return conf;
}

static char *
ngx_http_image_cache_merge_conf(ngx_conf_t *cf, void *parent, void *child)
{
    ngx_http_image_cache_conf_t *prev = parent;
    ngx_http_image_cache_conf_t *conf = child;

    ngx_conf_merge_value(conf->lookup_cache, prev->lookup_cache, 0);
    ngx_conf_merge_str_value(conf->group_name, prev->group_name, "");

    return NGX_CONF_OK;
}

static ngx_int_t
ngx_http_image_cache_init(ngx_conf_t *cf)
{
    ngx_http_handler_pt        *h; 
    ngx_http_core_main_conf_t  *cmcf;

    cmcf = ngx_http_conf_get_module_main_conf(cf, ngx_http_core_module);

    h = ngx_array_push(&cmcf->phases[NGX_HTTP_CONTENT_PHASE].handlers);
    if (h == NULL) {
        return NGX_ERROR;
    }   

    *h = ngx_http_image_cache_handler;

    return NGX_OK;
}
