import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import FormControl from '@mui/joy/FormControl';
import FormLabel from '@mui/joy/FormLabel';
import Input from '@mui/joy/Input';
import Button from '@mui/joy/Button';
import SepioLogo from './../image/Sepio_Logo.png';
import axios from 'axios';

export default function SignUp() {
  const navigate = useNavigate();
  const [formData, setFormData] = useState({ username: '', password: '' });
  const [status, setStatus] = useState('initial');

  const handleSubmit = (event) => {
    event.preventDefault();
    axios.post('/signup', formData)
      .then(response => {
        if (response.data.success) {
          navigate('/login');
        } else {
          setStatus('failure');
        }
      })
      .catch(error => {
        console.error('Sign up error:', error);
        setStatus('failure');
      });
  };

  const handleLoginRedirect = () => {
    navigate('/login');
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', background: '#778899', padding: '40px', borderRadius: '10px', maxWidth: '400px', margin: 'auto', marginTop: '100px' }}>
      <img src={SepioLogo} alt="Welcome" style={{ marginBottom: '20px', height: 70 }} />
      <form onSubmit={handleSubmit}>
        <FormControl>
          <FormLabel>Username</FormLabel>
          <Input
          placeholder = "Username"
            type="text"
            required
            value={formData.username}
            onChange={(e) => setFormData({ ...formData, username: e.target.value })}
          />
          <FormLabel>Password</FormLabel>
          <Input
          placeholder = "Password"
            type="password"
            required
            value={formData.password}
            onChange={(e) => setFormData({ ...formData, password: e.target.value })}
          />
          <Button
            variant="solid"
            color="primary"
            type="submit"
            sx={{ marginTop: '20px' }}
          >
            Sign Up
          </Button>
          {status === 'failure' && (
            <p style={{ color: 'red' }}>Sign up failed. Please try again.</p>
          )}
        </FormControl>
      </form>
      <Button
      variant = 'solid'
      color = 'secondary'
      sx = {{marginTop: '20px'}}
      onClick = {handleLoginRedirect}
      >
        Log In
      </Button>
    </div>
  );
}
