%JPEG解码
clear all;
close all;
ac_huffman_table = importdata('ac_huffman_table.txt');
dc_huffman_table = importdata('dc_huffman_table.txt');

file = fileread('total_bitstream.txt');
file = regexprep(file, '"', '');
fid = fopen('total_bitstream.txt', 'w');
fwrite(fid, file);
fclose(fid);
total_bitstream = importdata('total_bitstream.txt');
total_bitstream = strsplit(total_bitstream{1}, ',');