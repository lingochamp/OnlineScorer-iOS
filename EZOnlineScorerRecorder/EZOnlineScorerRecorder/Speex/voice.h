#ifndef VOICE_H
#define VOICE_H

/*
 *  * 初始化和销毁
 *   */
void voice_encode_init();
void voice_encode_release();
void voice_decode_init();
void voice_decode_release();
/*
 *  * 压缩编码
 *   * short lin[] 语音数据
 *    * int size 语音数据长度
 *     * char encoded[] 编码后保存数据的数组
 *      * int max_buffer_size 保存编码数据数组的最大长度
 *       */
int voice_encode(short in[], int size, 
        char encoded[], int max_buffer_size);
/*
 *  * 解码
 *   * char encoded[] 编码后的语音数据
 *    * int size 编码后的语音数据的长度
 *     * short output[] 解码后的语音数据
 *      * int max_buffer_size 保存解码后的数据的数组的最大长度
 *       */
int voice_decode(char encoded[], int size, 
        short output[], int max_buffer_size); 
#endif //define VOICE_H
