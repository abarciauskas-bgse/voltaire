const { generateQuery } = require('../measurements.js');

const baseQuery = `select * from "openaq_realtime_gzipped"."fetches_realtime_gzipped"`;
const limitClause = `limit 10`;
const event = {queryStringParameters: {}};

describe('query generation', () => {
  it('returns the expected default query', () => {
    expect(generateQuery(event)).toEqual(`${baseQuery} ${limitClause}`);
  });

  describe('with country parameter', () => {
    const eventWithQuery = {...event, queryStringParameters: {country: 'AD'}};

    it('returns the expected query with country', () => {
      expect(generateQuery(eventWithQuery)).toEqual(
        `${baseQuery} where "country" = 'AD' ${limitClause}`
      );
    });
  });

  describe('with country and city parameters', () => {
    const city = 'Escaldes-Engordany';
    const eventWithQuery = {
      ...event,
      queryStringParameters: {
        country: 'AD',
        city: city
      }
    };

    it('returns the expected query with country', () => {
      expect(generateQuery(eventWithQuery)).toEqual(
        `${baseQuery} where "country" = 'AD' and "city" = '${city}' ${limitClause}`
      );
    });
  });

  describe('with parameter[] parameters', () => {
    const eventWithQuery = {
      ...event,
      queryStringParameters: {
        'parameter[0]': 'co',
        'parameter[1]': 'pm25'
      }
    };

    it('returns the expected query with country', () => {
      expect(generateQuery(eventWithQuery)).toEqual(
        `${baseQuery} where "parameter" in ('co', 'pm25') ${limitClause}`
      );
    });
  });
});
