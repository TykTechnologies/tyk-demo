const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 4100;

// Middleware
app.use(cors());
app.use(express.json());

// Load country data
let countries = [];
try {
  const dataPath = path.join(__dirname, 'data', 'countries.json');
  const data = fs.readFileSync(dataPath, 'utf8');
  countries = JSON.parse(data);
} catch (error) {
  console.error('Error loading country data:', error);
}

// Routes
app.get('/', (req, res) => {
  res.json({ message: 'Countries API is running!' });
});

// Get all countries
app.get('/all', (req, res) => {
  res.json(countries);
});

// Get country by cca2 code
app.get('/cca2/:code', (req, res) => {
  const code = req.params.code.toUpperCase();
  const country = countries.find(c => c.cca2 === code);
  
  if (!country) {
    return res.status(404).json({ message: `Country with code ${code} not found` });
  }
  
  res.json(country);
});

// Get countries by name
app.get('/name/:name', (req, res) => {
  const name = req.params.name.toLowerCase();
  const matchedCountries = countries.filter(country => 
    country.name.common.toLowerCase().includes(name) || 
    (country.altSpellings && country.altSpellings.some(alt => alt.toLowerCase().includes(name)))
  );
  
  if (matchedCountries.length === 0) {
    return res.status(404).json({ message: `No countries found matching "${req.params.name}"` });
  }
  
  res.json(matchedCountries);
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
