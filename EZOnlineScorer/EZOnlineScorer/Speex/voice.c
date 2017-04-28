#include <Speex/Speex.h>
#include <string.h>
#include <stdio.h>
#include <stdbool.h>
#include "voice.h"

static int enc_frame_size;//压缩时的帧大小
static int dec_frame_size;//解压时的帧大小

static void *enc_state;
static SpeexBits ebits;
static bool is_enc_init = false;

static void *dec_state;
static SpeexBits dbits;
static bool is_dec_init = false;
//初始话压缩器
void voice_encode_init() {
    printf("enc init\n");
    int quality = 8;
    speex_bits_init(&ebits);
    enc_state = speex_encoder_init(&speex_wb_mode);
    speex_encoder_ctl(enc_state, SPEEX_SET_QUALITY, &quality);
    speex_encoder_ctl(enc_state, SPEEX_GET_FRAME_SIZE, &enc_frame_size);
    printf("enc_frame_size=%d\n",enc_frame_size);
    is_enc_init = true;
}
//销毁压缩器
void voice_encode_release() {
    printf("enc release\n");
    speex_bits_destroy(&ebits);
    speex_encoder_destroy(enc_state);
    is_enc_init = false;
}
//初始化解压器
void voice_decode_init() {
    printf("dec init\n");
    int enh = 1;
    speex_bits_init(&dbits);
    dec_state = speex_decoder_init(&speex_wb_mode);
    speex_decoder_ctl(dec_state, SPEEX_GET_FRAME_SIZE, &dec_frame_size);
    speex_decoder_ctl(dec_state, SPEEX_SET_ENH, &enh);
    printf("dec_frame_size=%d\n",dec_frame_size);
    is_dec_init = true;
}
//销毁解压器
void voice_decode_release() {
    printf("dec release\n");
    speex_bits_destroy(&dbits);
    speex_decoder_destroy(dec_state);
    is_dec_init = false;
}
//压缩语音流
int voice_encode(short in[], int size, 
        char encoded[], int max_buffer_size) {

    if (! is_enc_init) {
        voice_encode_init();
    }

    short buffer[enc_frame_size];
    char output_buffer[1024 + 4];
    int nsamples = (size - 1) / enc_frame_size + 1;
    int tot_bytes = 0;
    int i = 0;
    for (i = 0; i < nsamples; ++ i) {
        speex_bits_reset(&ebits);
        memcpy(buffer, in + i * enc_frame_size, 
                    enc_frame_size * sizeof(short));

        speex_encode_int(enc_state, buffer, &ebits);
        int nbBytes = speex_bits_write(&ebits, output_buffer + 4,
                                1024 - tot_bytes);
        memcpy(output_buffer, &nbBytes, 4);

        int len = 
                max_buffer_size >= tot_bytes + nbBytes + 4 ? 
                    nbBytes + 4 : max_buffer_size - tot_bytes;

        memcpy(encoded + tot_bytes, output_buffer, len * sizeof(char));
        
        tot_bytes += nbBytes + 4;
    }
    return tot_bytes;
}
//解压语音流
int voice_decode(char encoded[], int size, 
        short output[], int max_buffer_size) {

    if (! is_dec_init) {
        voice_decode_init();
    }

    char* buffer = encoded;
    short output_buffer[1024];
    int encoded_length = size;
    int decoded_length = 0;
    int i;

    for (i = 0; decoded_length < encoded_length; ++ i) {
        speex_bits_reset(&dbits);
        int nbBytes = *(int*)(buffer + decoded_length);
        speex_bits_read_from(&dbits, (char *)buffer + decoded_length + 4, 
                nbBytes);
        speex_decode_int(dec_state, &dbits, output_buffer);
        
        decoded_length += nbBytes + 4;
        int len = (max_buffer_size >= dec_frame_size * (i + 1)) ? 
                        dec_frame_size : max_buffer_size - dec_frame_size * i;
        memcpy(output + dec_frame_size * i, output_buffer, len * sizeof(short));
    }
    return dec_frame_size * i;
}
