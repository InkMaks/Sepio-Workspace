import React, { useState, useEffect } from 'react'

export const useLocalStorage = () => {
	const [state, setState] = useState(() => {
		const localUser = localStorage.getItem("userName");
		return localUser || '';
	});

	useEffect(() => {
		localStorage.setItem('userName', state);
	}, [state]);
	return [state, setState];
}