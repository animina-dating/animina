defmodule Animina.Repo.Migrations.AddHammingDistanceFunction do
  use Ecto.Migration

  def up do
    # Create a PostgreSQL function to calculate hamming distance between two bytea values.
    # This counts the number of differing bits between two binary hashes.
    #
    # The function:
    # 1. XORs the two bytea values byte-by-byte
    # 2. Counts the number of set bits (popcount) in the result
    #
    # Uses a lookup table approach for efficient bit counting.
    execute """
    CREATE OR REPLACE FUNCTION hamming_distance(a bytea, b bytea)
    RETURNS integer AS $$
    DECLARE
      i integer;
      xor_byte integer;
      distance integer := 0;
      -- Lookup table for popcount of a single byte (0-255)
      popcount integer[] := ARRAY[
        0,1,1,2,1,2,2,3,1,2,2,3,2,3,3,4,1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5,
        1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5,2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,
        1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5,2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,
        2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,3,4,4,5,4,5,5,6,4,5,5,6,5,6,6,7,
        1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5,2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,
        2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,3,4,4,5,4,5,5,6,4,5,5,6,5,6,6,7,
        2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,3,4,4,5,4,5,5,6,4,5,5,6,5,6,6,7,
        3,4,4,5,4,5,5,6,4,5,5,6,5,6,6,7,4,5,5,6,5,6,6,7,5,6,6,7,6,7,7,8
      ];
    BEGIN
      -- Handle NULL inputs
      IF a IS NULL OR b IS NULL THEN
        RETURN NULL;
      END IF;

      -- Handle different lengths by returning max distance
      IF length(a) != length(b) THEN
        RETURN 64; -- Max distance for 8-byte hash
      END IF;

      -- Calculate hamming distance using XOR and popcount lookup
      FOR i IN 0..length(a)-1 LOOP
        xor_byte := get_byte(a, i) # get_byte(b, i);
        distance := distance + popcount[xor_byte + 1]; -- PostgreSQL arrays are 1-indexed
      END LOOP;

      RETURN distance;
    END;
    $$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;
    """

    # Create an index on dhash for faster lookups
    execute """
    CREATE INDEX IF NOT EXISTS photo_blacklist_dhash_idx ON photo_blacklist (dhash);
    """
  end

  def down do
    execute "DROP INDEX IF EXISTS photo_blacklist_dhash_idx;"
    execute "DROP FUNCTION IF EXISTS hamming_distance(bytea, bytea);"
  end
end
