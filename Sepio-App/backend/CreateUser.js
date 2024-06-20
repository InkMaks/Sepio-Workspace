const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function createUser() {
    try{
      //Ensure the config was right
      await prisma.$connect();
      //Creating DB
        //await prisma.$executeRaw`CREATE DATABASE IF NOT EXISTS nodejs_login;`;
        //await prisma.$executeRaw`USE nodejs_login;`;

         // Modify user with mysql_native_password authentication plugin
    //await prisma.$executeRaw`ALTER USER 'Main_user'@'localhost' IDENTIFIED WITH mysql_native_password BY 'Sepio_password';`;
  //Granting privilages
  //await prisma.$executeRaw`GRANT ALL PRIVILEGES ON nodejs_login.* TO 'Main_user'@'localhost';`;
  //await prisma.$executeRaw`FLUSH PRIVILEGES;`;

  console.log('Connection Succesful!');
} catch (e) {
  console.error('Error creating user:', e);
  process.exit(1);
} finally {
  await prisma.$disconnect();
}
}

createUser().catch(console.error);