int main(){
    float theta;

    float rec_out;

    float rec_in[2];

    rec_in[1] = 542;
    rec_in[0] = 0;
    rec_out = efi(rec_in, 2);
    rec_out = rec_out/65564.0;
}