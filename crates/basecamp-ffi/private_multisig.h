/* Auto-generated C header for private_multisig FFI. DO NOT EDIT. */
#ifndef PRIVATE_MULTISIG_FFI_H
#define PRIVATE_MULTISIG_FFI_H

#ifdef __cplusplus
extern "C" {
#endif

/* create_multisig instruction */
char* private_multisig_create_multisig(const char* args_json);

/* create_proposal instruction */
char* private_multisig_create_proposal(const char* args_json);

/* approve instruction */
char* private_multisig_approve(const char* args_json);

/* execute instruction */
char* private_multisig_execute(const char* args_json);

/* fetch config account state */
char* private_multisig_fetch_config(const char* args_json);

/* fetch proposal account state */
char* private_multisig_fetch_proposal(const char* args_json);

/* wallet helpers */
char* private_multisig_check_connection(const char* args_json);
char* private_multisig_inspect_account(const char* args_json);
char* private_multisig_list_accounts(const char* args_json);
char* private_multisig_create_account(const char* args_json);

void private_multisig_free_string(char* s);
char* private_multisig_version(void);
char* private_multisig_program_id(void);
char* private_multisig_decode_account(const char* args_json);

#ifdef __cplusplus
}
#endif

#endif /* PRIVATE_MULTISIG_FFI_H */
