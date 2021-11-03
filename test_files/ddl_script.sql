-- автобус, троллейбус, трамвай, ТУАХ, электробус
CREATE TYPE vehicle_type AS ENUM ('bus', 'trolleybus', 'imc', 'electric_bus');

/*
    Модель транспортного средства включает:
    - название типа ТС (автобус, троллейбус, трамвай, ТУАХ, электробус)
    - название модели, определяемое производителем (<<ПКТС-6281 «Адмирал»>>)
    - вместимость в количестве пассажиров.
*/
CREATE TABLE vehicle_model
(
    id       SERIAL PRIMARY KEY,
    name     TEXT         NOT NULL, -- название модели
    type     vehicle_type NOT NULL, -- тип ТС
    capacity INTEGER      NOT NULL CHECK (capacity > 0),
    UNIQUE (name, type)
);

/*
тип ТС (автобус, троллейбус, трамвай, ТУАХ, электробус)
*/
CREATE TYPE vehicle_state AS ENUM ('working', 'non_critical_faults', 'repair_required');

/*
    Используются разнообразные транспортные средства: автобусы, троллейбусы и трамваи.
    У каждого транспортного средства (ТС) есть:
    - бортовой номер-идентификатор
    - год его выпуска
    - актуальное состояние -- значение из конечного множества:
    -- <<исправен>>
    -- <<некритические неисправности>>
    -- <<требует ремонта>>
    - модель ТС
*/
CREATE TABLE vehicle
(
    id           SERIAL PRIMARY KEY,                                   -- бортовой номер
    model_id     INTEGER       NOT NULL REFERENCES vehicle_model (id), -- модель
    state        vehicle_state NOT NULL,                               -- актуальное состояние
    release_date DATE          NOT NULL                                -- дата выпуска
);

/*
    В городе есть некоторое множество остановок ОТ.

    У каждой остановки есть:
    - персональный номер и адрес, записываемый в довольно произвольном виде
        (например, <<перекрёсток улиц Ленина и Николая Второго>>)
    - количество платформ -- мест для размещения одного ТС.

    Платформы одной остановки пронумерованы начиная с 1.
*/
CREATE TABLE stop
(
    id               SERIAL  NOT NULL PRIMARY KEY,
    name             TEXT    NOT NULL,
    platforms_amount INTEGER NOT NULL CHECK (platforms_amount > 0),
    UNIQUE (name)
);

/*
    Вы определяете маршруты ТС.
    У маршрута есть:
    - уникальный номер, известный пассажирам
    - тип ТС, который его обслуживает
    - остановка, условно называемая начальной и условная конечная остановка.

    В реальности ТС ходят по маршруту туда-сюда и вполне могут двигаться в обратном направлении,
    от <<конечной>> остановки к <<начальной>>.
*/
CREATE TABLE route
(
    id            SERIAL PRIMARY KEY,
    vehicle_type  vehicle_type NOT NULL,
    first_stop_id INTEGER      NOT NULL REFERENCES stop (id),
    last_stop_id  INTEGER      NOT NULL REFERENCES stop (id)
);

/*
    Транспорт ходит по расписанию, которое тоже хранится в базе
    и показывается пассажирам на вашем сайте.

    В расписании написано:
    - с точностью до минуты, в какой момент времени
    - ТС какого маршрута прибыть
    - на ту или иную остановку
    - и к какой платформе должен подъехать.
    - расписание в будние и выходные может отличаться

    ТС стоит у платформы одну минуту,
    и разумеется никакое другое ТС в это время у этой платформы стоять не может.
*/
CREATE TABLE schedule
(
    route_id     INTEGER NOT NULL REFERENCES route (id),
    arrival_time TIME    NOT NULL,
    stop_id      INTEGER NOT NULL REFERENCES stop (id),
    platform     INTEGER NOT NULL CHECK (platform > 0),
    is_weekend   BOOLEAN NOT NULL,
    PRIMARY KEY (route_id, arrival_time, stop_id, platform, is_weekend),
    -- одновременно на одной остановке и одной платформе не может быть несколько ТС
    UNIQUE (arrival_time, stop_id, platform, is_weekend)
);

/*
     Выполнять наряд назначается водитель, от которого нам интересно
     -ФИО
     -номер его служебного удостоверения
 */
CREATE TABLE driver
(
    id              SERIAL PRIMARY KEY,
    first_name      TEXT NOT NULL,
    last_name       TEXT NOT NULL,
    patronymic_name TEXT
);

/*
    В каждый конкретный день вы составляете так называемые наряды на работу.
    Это задание:
    -какому-то конкретному ТС
    -следовать в этот день по заданному маршруту,
    -начиная с заданной остановки
    -в указанное время.
    -Выполнять наряд назначается водитель
*/
CREATE TABLE work_order
(
    id          SERIAL PRIMARY KEY,
    vehicle_id  INTEGER NOT NULL REFERENCES vehicle (id),
    route_id    INTEGER NOT NULL REFERENCES route (id),
    route_start INTEGER NOT NULL REFERENCES stop (id), -- с какой остановки начинается маршрут
    start_date  DATE    NOT NULL,
    start_time  TIME    NOT NULL,
    driver_id   INTEGER NOT NULL REFERENCES driver (id),
    UNIQUE (vehicle_id, start_date, start_time, driver_id)
);

/*
     Диспетчерская следит за выполнением наряда при помощи GPS и записывает:
     -исполнителя наряда
     -в какое время он действительно прибыл
     -на ту или иную остановку.
 */
CREATE TABLE accuracy
(
    work_order_id  INTEGER NOT NULL REFERENCES work_order (id),
    stop_id        INTEGER NOT NULL REFERENCES stop (id),
    actual_arrival TIME    NOT NULL,
    PRIMARY KEY (work_order_id, stop_id, actual_arrival)
);

/*
    Есть несколько типов оплаты поездок, каждый тип характеризуется:
    -именем
    -стоимостью.
*/
CREATE TABLE ticket_type
(
    id   SERIAL PRIMARY KEY,
    name TEXT           NOT NULL,
    cost DECIMAL(10, 2) NOT NULL CHECK (cost > 0)
);

/*
    В конце каждого наряда из валидационной системы забирается статистика
    по использованию билетов каждого типа, которая содержит:
    -ссылку на тип билета
    -количество использований билетов этого типа за наряд
    -дату наряда.
*/
CREATE TABLE ticket_validation_stats
(
    ticket_type_id INTEGER NOT NULL REFERENCES ticket_type (id),
    n_validations  INTEGER NOT NULL CHECK (n_validations >= 0),
    date           DATE    NOT NULL,
    UNIQUE (ticket_type_id, date)
)
