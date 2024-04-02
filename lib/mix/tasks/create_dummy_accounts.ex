defmodule Mix.Tasks.CreateDummyAccounts do
  @moduledoc """
  This task creates dummy accounts for development.
  """

  use Mix.Task
  alias Animina.Accounts.User
  alias Faker.Person
  alias Faker.Phone

  def run(args) do
    Mix.Task.run("app.start", [])

    (List.first(args) || "100")
    |> String.to_integer()
    |> generate_users()

    User.read!()
    |> print_table()
  end

  def generate_users(0) do
  end

  def generate_users(counter) do
    1..counter
    |> Enum.each(fn _ ->
      height = Enum.take_random(Enum.to_list(150..210), 1) |> hd
      birthday = Faker.Date.date_of_birth()
      age = (Date.diff(Date.utc_today(), birthday) / 365) |> round
      gender = Enum.take_random(["male", "female"], 1) |> hd

      User.create!(%{
        email: Faker.Internet.email(),
        username: Faker.Internet.user_name() |> String.slice(0..14),
        name: Faker.Person.name(),
        zip_code: random_zip_code(),
        language: "DE-de",
        legal_terms_accepted: true,
        gender: gender,
        height: height,
        mobile_phone: random_mobile_phone_number(),
        birthday: birthday,
        hashed_password: Faker.UUID.v4(),
        occupation: Person.En.title_descriptor(),
        minimum_partner_height: height - 30,
        maximum_partner_height: height + 15,
        minimum_partner_age: minimum_partner_age(age),
        maximum_partner_age: age + 10,
        partner_gender: opposite_gender(gender),
        search_range: hd(Enum.take_random([5, 10, 20, 50, 100, 250], 1))
      })
    end)
  end

  def print_table(users) do
    IO.puts("|--------------------------|--------|-----------------|---------|-----|")
    IO.puts("| Name                     | Gender | Username        | ZipCode | Age |")
    IO.puts("|--------------------------|--------|-----------------|---------|-----|")

    Enum.each(users, fn user ->
      username = "#{user.username}"

      IO.puts(
        "| #{user.name |> String.pad_trailing(24)} | #{user.gender |> String.pad_trailing(6)} | #{String.pad_trailing(username, 15)} | #{String.pad_trailing(user.zip_code, 7)} | #{user.age |> Integer.to_string() |> String.pad_trailing(3)} |"
      )
    end)

    IO.puts("|--------------------------|--------|-----------------|---------|-----|")
  end

  def random_zip_code do
    Enum.take_random(
      [
        "56068",
        "56070",
        "56072",
        "56073",
        "56075",
        "56076",
        "56077",
        "56333",
        "56564",
        "56566",
        "56567"
      ],
      1
    )
    |> hd
  end

  def random_mobile_phone_number do
    hd(Enum.take_random(["0171", "0151", "0172", "0160", "0170", "0157"], 1)) <>
      Phone.EnUs.subscriber_number(8)
  end

  def opposite_gender("male") do
    "female"
  end

  def opposite_gender("female") do
    "male"
  end

  def minimum_partner_age(age) do
    if age < 29 do
      18
    else
      age - 10
    end
  end

  def random_photo_url("male") do
    Enum.take_random(
      [
        "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?q=80&w=2487&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
        "https://images.unsplash.com/photo-1590086782792-42dd2350140d?q=80&w=2487&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
        "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=2487&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
        "https://plus.unsplash.com/premium_photo-1675804300600-888042d9e90d?q=80&w=2487&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"
      ],
      1
    )
    |> hd
  end

  def random_photo_url("female") do
    Enum.take_random(
      [
        "https://images.unsplash.com/photo-1544005313-94ddf0286df2?q=80&w=2488&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
        "https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?q=80&w=2550&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
        "https://images.unsplash.com/photo-1607569708758-0270aa4651bd?q=80&w=2487&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
        "https://images.unsplash.com/photo-1578856221991-88f493e5d59e?q=80&w=2449&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"
      ],
      1
    )
    |> hd
  end
end
