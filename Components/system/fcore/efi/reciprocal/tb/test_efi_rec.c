int main(){
    float theta;

    float rec_out;

    float rec_in[2];

    rec_in[1] = 225;
    rec_in[0] = 0;
    rec_out = efi(rec_in, 2);
    rec_out = itf(rec_out)/65564.0;
}