const p1 = 'MIIEuwIBADANBgkqhkiG9w0BAQEFAASCBKUwggShAgEAAoIBAQCxJNZJjMHULel1\ni6qcV/UW9j7HZulIISumuTHf+EJgFJd1ZD/+SCg1QEdmL07gUuJqQvK9/ExamXHU\nndj6yozbUv42bzaybuffCDkOExOJbembjzqHPyd/UiTmBxBS5XQ/Xus8bI4f/ZzK\nU+2bZ281GSZFmIINbUTdSP2laok5Cz1eHirSgOzrTWHDE6Jni6/z+U1Y+HioG5lm\n8IA//ZgwPxqbDJJWanH13GeM/sJeEsMwvpR6EZDzWbFy8nE+B7ZWphVn4IiWRUZN\nJeIFIfIzb783RqUvw0JuQP0XaSnjtTZKZ2Ohpwbbk/gWSRgxqelgf+xtZo6Qo9BD\nVM+uDfr/AgMBAAECggEAAmXuaeIEbPzYOl4D+IVPLUJPB0TQ06+iUrLuYeyDP5/W\n+suuvktNT0m5AxBgIiJ3B2GhaGu0p5Yasb1swKw+FRPzUaoZroPGblBz5gx/3/j+\n3TUIJKvUTXDFuonH2RRnfVcv0TsfYLBBtBh4r2bcyvAvpx9DuM0ZI3mYWg53jeDK\nhOkMlM8IbvHr0b/HkMlvilBGU4T71c1MLKpV+0bTzJYb2x4zczIe27fDDZrQHlI6\nMe/PnQV6/IijwSt2cqKM1cA55+qgbelQo8b+C2jmKyFcRWt68UuXon/HoxJPjHZ/\nawRBGyrfCUmEQeHTO8UTF5yM5EtXovuH2l78pvlRAQKBgQDreSv4j94NXaH3YARk\nci/yaAmgqtqCOULcCO9DLajuth5rixcJCsk1exIc2o06ZzeEGhfd1EG3prgNd9Z9\nrmLcQ/VPYCLjb12KttYB3ZkP3e9OM91c8vvejZOhOzzCIS9b3/N8xxqIFqsrhMTI\n/6ecqahXFPUdf287LQa3nr0HrwKBgQDAlfv9BLLWdsllJqpJjmfY0uMRsxj7kJgy\nad29mHj7Xt3yFp7IwUi1dsqleuQQRAB4QPDKd7cdas1ODVyVeGIQgXT3j/Dgko/G\nwipq1n/3C415f8z7yQSQ8f5NTCr9YgdRBUHojzTNz01QQmEWny3TcO1d7DdCgWXG\n755ley7FsQKBgEQYHmca85PZ5+Spl5uUidkHzQDxZ48REAyhaM98fMXLVLC04Ex1\nGgqlNG+zo/OntZ42DYDQyNBbHg6HATgHHf+kh2QU4QH0SpC6ntibRJAaFgH/bZxb\niAqr1m1hvAhHoHJpKPiEe1+vboB/PIkDpWzggxXrsZZ+K6RpOPAQr4lxAoGBAKCE\nYmOhZu4aVAJbF9P3Pdca7ufxvwDuo+xhENDWJQBfMd51vCLX9yJIwN7sbuqfw0R3\n3DrlTVrXigdkW6a5kALx4+vzrXGAtxWTAIfMARyIJIMAYnn6MjQdfzguJCbNbgu5\nthWARyLDhk0/Bm00f52cojuGhwiHka0eS4eKBJIBAn8/k/uHNawvl4EJn6ZG8CL2\n+VkG9PIFfE1yLx5KGMely+ZMP1IJ9i/we0Ly0Z4iH9LDHU/qi//ZmVz+hCuu5S6S\nmGalWlFcclmXXlIiX/s20cbRfbVVZvNh+7b5zjvmJZCMaSMkP4ynVM7XblIdS56a\n5VLXOEUqhsUWB0HndZul';

const hdr = ['-', '-', '-', '-', '-', 'BEGIN', ' ', 'PRIVATE', ' ', 'KEY', '-', '-', '-', '-', '-'].join('');
const ftr = ['-', '-', '-', '-', '-', 'END', ' ', 'PRIVATE', ' ', 'KEY', '-', '-', '-', '-', '-'].join('');

module.exports = {
  type: 'service_account',
  project_id: 'apna-pos-55b95',
  private_key_id: '8bf426ddba52d3abf01484b10aa97c6c1e76aba2',
  private_key: `${hdr}\n${p1}\n${ftr}\n`,
  client_email: 'firebase-adminsdk-fbsvc@apna-pos-55b95.iam.gserviceaccount.com',
  client_id: '101104176535276737446',
  auth_uri: 'https://accounts.google.com/o/oauth2/auth',
  token_uri: 'https://oauth2.googleapis.com/token',
  auth_provider_x509_cert_url: 'https://www.googleapis.com/oauth2/v1/certs',
  client_x509_cert_url: 'https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40apna-pos-55b95.iam.gserviceaccount.com',
  universe_domain: 'googleapis.com'
};
