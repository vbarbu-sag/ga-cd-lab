import { useEffect, useState } from 'react'
import './App.css'

async function getWeatherForecast() {
  try {
    const resp = await fetch(`${import.meta.env.API_URL}/weatherforecast`);
    const forecast = await resp.json();
    return forecast;
  } catch (e) {
    console.error(`oops something went wrong: ${e.message}`);
    return [];
  }
}

function ForecastRow({ date, temperatureC, summary }) {
  const formattedDate = new Date(date).toLocaleDateString();
  return (
    <tr>
      <td> {formattedDate} </td>
      <td> {temperatureC} </td>
      <td> {summary ?? '-'} </td>
    </tr>
  );
}

export default function App() {
  const [forecast, setForecast] = useState([]);
  useEffect(() => {
    getWeatherForecast().then(setForecast);
  }, []);
  return (
    <div>
      <table>
        <thead>
          <tr>
            <th>Date</th>
            <th>Temperature (C)</th>
            <th>Summary</th>
          </tr>
        </thead>
        <tbody>
          {forecast.map((x, index) => (
            <ForecastRow key={index} {...x} />
          ))}
        </tbody>
      </table>
    </div>
  );
}
