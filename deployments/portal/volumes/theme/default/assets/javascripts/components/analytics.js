export function GetTrafficChartData({timeUnit, apps, updateTab, from, to, codes}) {
    const ctx = document.getElementById("traffic-chart");
    if (!ctx) return
    if (!timeUnit) {
        timeUnit = "day"
    }
    let dataUrl = `/portal/private/analytics/api/chart/traffic?timeUnit=${timeUnit}`;
    if (apps) {
        dataUrl = dataUrl + `&apps=${apps}`
    }
    if (from && to) {
        dataUrl = dataUrl + `&from=${from}&to=${to}`
    }
    if (codes) {
        dataUrl = dataUrl + `&codes=${codes}`
    }
    getData(dataUrl).then((data) => {
        if (updateTab) {
            let trafficVsLastWeek = document.getElementById("traffic-vs-last-week");
            let defVal = document.getElementById("traffic-vs-last-week-dafault");
            let totalCalls = document.getElementById("total-api-calls");
            totalCalls.innerText = data.TotalAPICalls;
            if (data.Percentage > 0) {
                removeArrow(trafficVsLastWeek, defVal, true);
                trafficVsLastWeek.classList.add("arrow-up");
            }else if (data.Percentage < 0) {
                removeArrow(trafficVsLastWeek, defVal, true);
                trafficVsLastWeek.classList.add("arrow-down");
            }else{
                removeArrow(trafficVsLastWeek, defVal, false);
                defVal.classList.add("d-block");
            }
        }
        const type = 'line';
        const options = {
            elements: {
                point: {
                    radius: 4, // Increase point radius to make them visible
                    hoverRadius: 6
                },
                line: {
                    tension: 0, // Use straight lines between points
                    spanGaps: false // Don't span gaps (treat zero values as data points)
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    stacked: true,
                    title: {
                        display: true,
                        text: "No of API Calls"
                    },
                    ticks: {
                        font: {
                            size: 12,
                        }
                    }
                },
                x: {
                    ticks: {
                        font: {
                            size: 12,
                        }
                    }
                }
            },
            plugins: {
                legend: {
                    labels: {
                    usePointStyle: true,
                    font: {
                        size: 14
                    }
                    },
                    position: "top",
                    align: "end"
                },
            }  
        }
        buildChart(ctx, type, data.Data, options);
    }).catch((error) => console.error(`Could not fetch data: ${error}`));
}

function removeArrow(elem1, elem2, hide) {
    elem1.classList.remove("arrow-up","arrow-down");
    elem2.classList.remove("d-none","d-block");
    if (hide) {
        elem2.classList.add("d-none");
    }
}
async function getData(url) {
    try {
        let data = await fetch(url);
        let res = await data.json();
        return res.data;
    } catch (error) {
        console.error(`Could not fetch data: ${error}`);
    }
}

function buildChart(ctx, type, data, options, plugins) {
    let args = {
        type,
        data,
        options
    }
    if (plugins) {
        args["plugins"] = plugins
    }
    let chartStatus = Chart.getChart(ctx);
    if (chartStatus !== undefined) {
        chartStatus.destroy();
    }
    new Chart(ctx,args)
}

export function ExportCSV({chartID, buttonID, filename}) {
    document.getElementById(buttonID)?.addEventListener("click", () => {
        let chart = Chart.getChart(chartID);
        if (chart != undefined) {
            downloadCSV({
                filename: filename,
                data: chart.config._config.data
            })
        }
    })
}

function convertChartDataToCSV(args) {
    let result, columnDelimiter, lineDelimiter, labels, data;
  
    data = args.data.data || null;
    if (data == null || !data.length) {
      return null;
    }
    labels = args.labels || null;
    if (labels == null || !labels.length) {
      return null;
    }
  
    columnDelimiter = args.columnDelimiter || ',';
    lineDelimiter = args.lineDelimiter || '\n';
  
    result = '' + columnDelimiter;
    result += labels.join(columnDelimiter);
    result += lineDelimiter;
  
    result += args.data.label.toString();
  
    for (let i = 0; i < data.length; i++) {
      result += columnDelimiter;
      if (typeof data[i] === "object") {
        result += data[i].y
      }else {
        result += data[i];
      }
    }
    result += lineDelimiter;
  
    return result;
}
  
function downloadCSV(args) {
    var data, filename, link;
    var csv = "";
    for (var i = 0; i < args.data.datasets.length; i++) {
        csv += convertChartDataToCSV({
        data: args.data.datasets[i],
        labels: args.data.labels
        });
    }
    if (csv == null) return;
    filename = args.filename || 'chart-data.csv';
    if (!csv.match(/^data:text\/csv/i)) {
        csv = 'data:text/csv;charset=utf-8,' + csv;
    }

    data = encodeURI(csv);
    link = document.createElement('a');
    link.setAttribute('href', data);
    link.setAttribute('download', filename);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
}

export function GetOverviewChartData(from, to, appID) {
    const charts = [
        {
            ctx: document.getElementById("hits-vs-errors-chart")?.getContext('2d'),
            type: "line",
            data: "SuccessVsErrors",
            options: {
                elements: {
                    point:{
                        radius: 0
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                    }
                }
            }
        },
        {
            ctx: document.getElementById("error-rates-chart")?.getContext('2d'),
            type: "bar",
            data: "ErrorRates",
            options: {
                indexAxis: 'y',
            }
        },
        {
            ctx: document.getElementById("error-breakdown-chart")?.getContext('2d'),
            type: "pie",
            data: "ErrorBreakdown",
            options: {
                scales: {
                    y: {
                        beginAtZero: true,
                    }
                }
            }
        }
    ]
    if (!appID) {
        appID = document.getElementById("analytics-overview-select-apps")?.value
    }
    let dataUrl = `/portal/private/analytics/api/chart/overview?app-id=${appID}`
    if (from && to) {
        dataUrl = dataUrl + `&from=${from}&to=${to}`
    }

    if (!charts[0].ctx) return
    getData(dataUrl).then((data) => {
        if (!data) return
        for (const chart of charts) {
            buildChart(chart.ctx, chart.type, data[chart.data], chart.options);
        }
        document.getElementById("usageTabTotalAPICalls").innerText = data.UsageMetadata.TotalAPICalls;
        document.getElementById("usageTabSuccess").innerText = data.UsageMetadata.Success;
        document.getElementById("usageTabErrors").innerText = data.UsageMetadata.Errors;
    }).catch((error) => console.error(`Could not fetch data: ${error}`));
}

export function HandleCalendar(calendarID) {
    if (!document.querySelector(calendarID)) return
    flatpickr(calendarID, {
        mode: "range",
        dateFormat: "d-m-Y",
        maxDate:"today",
        onChange: function (selectedDates, dateStr, instance) {
            let from =  getFormattedDate(selectedDates[0]); 
            let to = getFormattedDate(selectedDates[1]);
            let text = document.getElementById("analytics-date-picker-selected-range");
            text.innerText = `${from} to ${to}`
            GetOverviewChartData(from, to);
            UpdateTrafficChart({
                from: from,
                to: to,
                updateTab: true,
                active: true
            });
            UpdateErrorRateChart({
                from: from,
                to: to,
                updateTab: true,
                active: true
            });
            UpdateLatencyChart({
                from: from,
                to: to,
                updateTab: true,
                active: true
            });
        },
    });
}

function getFormattedDate(date) {
    if (!date) return
    let day = date.getDate() >= 10 ? date.getDate() : "0" +  date.getDate()
    let month = date.getMonth() + 1
    let year = date.getFullYear()
    return `${day}-${month}-${year}`
}

export function UpdateTrafficChart({from, to, updateTab, timeUnit, active}) {
    if (!active) return
    //get time period apps and codes
    if (!timeUnit) {
        timeUnit = document.getElementById("traffic-time-unit")?.value;
    }
    let apps = [];
    Array.from(document.getElementById("apps-filter-traffic-chart")?.children)?.forEach(element => {
        let text = element.innerText.trim().split("\n").map(line => line.trim()).join("\n");
        text != "All apps" ? apps.push(text) : null
    });
    let codes = [];
    Array.from(document.getElementById("codes-filter-traffic-chart")?.children)?.forEach(element => {
        let text = element.innerText;
        text != "" ? codes.push(text) : null
    });
    GetTrafficChartData({
        timeUnit: timeUnit,
        apps: apps.join(","),
        updateTab: updateTab,
        from: from,
        to: to,
        codes: codes.join(",")
    });
}

export function GetTimeRange() {
    let from = "";
    let to = "";
    let range = document.getElementById("analytics-date-picker-selected-range")?.innerText.split("to");
    if (range.length == 2) {
        from = range[0].trim()
        to = range[1].trim()
    }
    return {
        from,
        to
    }
}

export function FilterObserver(targetID, handler) {
    const targetNode = document.getElementById(targetID);
    if (!targetNode) return
    const config = { attributes: true, childList: true, subtree: true };
    if (targetNode == null) {
        return;
    }

    // Callback function to execute when mutations are observed
    const callback = function(mutationList, observer) {
        for (const mutation of mutationList) {
            if (mutation.type === 'childList') {
                const children = Array.from(targetNode?.children)
                if (children.length > 0) {
                    handler();
                }
            }
        }
    };
    const observer = new MutationObserver(callback);
    // Start observing the target node for configured mutations
    observer.observe(targetNode, config);
}

export function FilterObserverHanlderForTrafficChart() {
    let trafficChartActive = document.getElementById("traffic-chart-tab")?.classList.contains("active");
    let range = GetTimeRange();
    let from = range.from;
    let to = range.to;
    UpdateTrafficChart({
        from: from,
        to: to,
        updateTab: false,
        active: trafficChartActive
    });
}
export function FilterObserverHanlderForErrorRateChart() {
    let errorRateChartActive = document.getElementById("error-rate-chart-tab")?.classList.contains("active");
    let range = GetTimeRange();
    let from = range.from;
    let to = range.to;
    UpdateErrorRateChart({
        from: from,
        to: to,
        updateTab: false,
        active: errorRateChartActive
    });
}
export function FilterObserverHanlderForLatencyChart() {
    let latencyChartActive = document.getElementById("latency-chart-tab")?.classList.contains("active");
    let range = GetTimeRange();
    let from = range.from;
    let to = range.to;
    UpdateLatencyChart({
        from: from,
        to: to,
        updateTab: false,
        active: latencyChartActive
    });
}
export function OnChangeHandlerForFilters(filterID, handler) {
    document.getElementById(filterID)?.addEventListener('change', (e) => {
        handler(e);
    })
}

export function OnChangeHandlerTrafficTimeUnit(event) {
    let value = event.target.value;
    let range = GetTimeRange();
    let from = range.from;
    let to = range.to;
    UpdateTrafficChart({
        from: from,
        to: to,
        updateTab: false,
        active: true,
        timeUnit: value
    });
}

export function OnChangeHandlerOverviewApps(event) {
    let value = event.target.value;
    let range = GetTimeRange();
    let from = range.from;
    let to = range.to;
    GetOverviewChartData(from, to, value)
}

export function OnChangeHandlerStatisticsErrorRate(event) {
    let value = event.target.value;
    let range = GetTimeRange();
    let from = range.from;
    let to = range.to;
    UpdateErrorRateChart({
        from: from,
        to: to,
        updateTab: false,
        active: true,
        stats: value
    });
}

export function OnChangeHandlerErrorRateTimeUnit(event) {
    let value = event.target.value;
    let range = GetTimeRange();
    let from = range.from;
    let to = range.to;
    UpdateErrorRateChart({
        from: from,
        to: to,
        updateTab: false,
        active: true,
        timeUnit: value
    });
}

export function OnChangeHandlerLatencyTimeUnit(event) {
    let value = event.target.value;
    let range = GetTimeRange();
    let from = range.from;
    let to = range.to;
    UpdateLatencyChart({
        from: from,
        to: to,
        updateTab: false,
        active: true,
        timeUnit: value
    });
}

export function GetErrorRateChartData({timeUnit, stats, apps, from, to, updateTab, codes}) {
    const ctx = document.getElementById("error-rate-chart");
    if (!ctx) return
    if (!stats) {
        stats = "error-rate"
    }
    if (!timeUnit) {
        timeUnit = "hour"
    }
    let dataUrl = `/portal/private/analytics/api/chart/error?statistics=${stats}&timeUnit=${timeUnit}`;
    if (apps) {
        dataUrl = dataUrl + `&apps=${apps}`
    }
    if (from && to) {
        dataUrl = dataUrl + `&from=${from}&to=${to}`
    }
    if (codes) {
        dataUrl = dataUrl + `&codes=${codes}`
    }
    getData(dataUrl).then((data) => {
        if (!data) return
        if (updateTab) {
            let averageErrorRate = data?.AverageErrorRate || 0;
            let changeInErrorRate = data?.ChangeInErrorRate || 0;
            let errorRateAverage = document.getElementById("error-rate-average");
            let errorRateVsLastWeek = document.getElementById("error-rate-vs-last-week");
            let defVal = document.getElementById("error-rate-vs-last-week-dafault");
            errorRateAverage.innerText = averageErrorRate + " %";
            if (changeInErrorRate > 0) {
                removeArrow(errorRateVsLastWeek, defVal, true);
                errorRateVsLastWeek.classList.add("arrow-up");
            }else if (changeInErrorRate < 0) {
                removeArrow(errorRateVsLastWeek, defVal, true);
                errorRateVsLastWeek.classList.add("arrow-down");
            }else{
                removeArrow(errorRateVsLastWeek, defVal, false);
                defVal.classList.add("d-block");
            }
        }
        const type = 'line';
        const options = {
            elements: {
                point: {
                    radius: 4, // Increase point radius to make them visible
                    hoverRadius: 6
                },
                line: {
                    tension: 0, // Use straight lines between points
                    spanGaps: false // Don't span gaps (treat zero values as data points)
                }
            },
            tooltips: {
                mode: 'index',
                intersect: false,
            },
            hover: {
                mode: 'nearest',
                intersect: true
            },
            scales: {
                y: {
                    stacked: data.Stacked,
                    beginAtZero: true,
                    title: {
                        display: true,
                        text: data.YAxisText,
                    },
                    ticks: {
                        font: {
                            size: 12,
                        }
                    },
                },
                x: {
                    ticks: {
                        font: {
                            size: 12,
                        }
                    }
                },
            },
            plugins: {
                legend: {
                    labels: {
                    usePointStyle: true,
                    font: {
                        size: 14
                    }
                    },
                    position: "top",
                    align: "end"
                },
            },
        };
        buildChart(ctx, type, data.ErrorChart, options);
    }).catch((error) => console.error(`Could not fetch data: ${error}`));
}

export function GetLatencyChartData({timeUnit, apps, from, to, updateTab}) {
    const ctx = document.getElementById("latency-chart");
    if (!ctx) return
    if (!timeUnit) {
        timeUnit = "hour"
    }
    let dataUrl = `/portal/private/analytics/api/chart/latency?&timeUnit=${timeUnit}`;
    if (apps) {
        dataUrl = dataUrl + `&apps=${apps}`
    }
    if (from && to) {
        dataUrl = dataUrl + `&from=${from}&to=${to}`
    }
    getData(dataUrl).then((data) => {
        if (!data) return
        if (updateTab) {
            let averageLatency = data?.AverageLatency || 0;
            let changeInLatency = data?.ChangeInErrorRate || 0;
            let latencyAverage = document.getElementById("latency-average");
            let latencyVsLastWeek = document.getElementById("latency-vs-last-week");
            let defVal = document.getElementById("latency-vs-last-week-dafault");
            latencyAverage.innerText = averageLatency + " ms";
            if (changeInLatency > 0) {
                removeArrow(latencyVsLastWeek, defVal, true);
                latencyVsLastWeek.classList.add("arrow-up");
            }else if (changeInLatency < 0) {
                removeArrow(latencyVsLastWeek, defVal, true);
                latencyVsLastWeek.classList.add("arrow-down");
            }else{
                removeArrow(latencyVsLastWeek, defVal, false);
                defVal.classList.add("d-block");
            }
        }
        const type = 'line';
        const options = {
            elements: {
                point: {
                    radius: 4, // Increase point radius to make them visible
                    hoverRadius: 6
                },
                line: {
                    tension: 0, // Use straight lines between points
                    spanGaps: false // Don't span gaps (treat zero values as data points)
                }
            },
            tooltips: {
                mode: 'index',
                intersect: false,
            },
            hover: {
                mode: 'nearest',
                intersect: true
            },
            scales: {
                y: [{
                    ticks: {
                        beginAtZero:true,
                        font: {
                            size: 12,
                        }
                    }
                }]
            },
            plugins: {
                legend: {
                    labels: {
                    usePointStyle: true,
                    font: {
                        size: 14
                    }
                    },
                    position: "top",
                    align: "end"
                },
            }
        };
        buildChart(ctx, type, data.LatencyChart, options);
    }).catch((error) => console.error(`Could not fetch data: ${error}`));
}

function UpdateErrorRateChart({from, to, updateTab, timeUnit, stats, active}) {
    if (active) {
        if (!stats) {
            stats = document.getElementById("error-rate-statistics")?.value
        }
        let apps = [];
        Array.from(document.getElementById("apps-filter-error-rate-chart")?.children)?.forEach(element => {
            let text = element.innerText.trim().split("\n").map(line => line.trim()).join("\n");
            if (text != "All apps") {
                let id = document.getElementById(text).dataset.appid;
                apps.push(id);
            }
        });
        let codes = [];
        Array.from(document.getElementById("codes-filter-error-rate-chart")?.children)?.forEach(element => {
            let text = element.innerText;
            text != "" ? codes.push(text) : null
        });
        GetErrorRateChartData({
            timeUnit,
            stats,
            apps,
            from,
            to,
            updateTab,
            codes: codes.join(",")
        });
    }
}

function UpdateLatencyChart({from, to, updateTab, timeUnit, active}) {
    if (active) {
        let apps = [];
        Array.from(document.getElementById("apps-filter-latency-chart")?.children).forEach(element => {
            let text = element.innerText.trim().split("\n").map(line => line.trim()).join("\n");
            if (text != "All apps") {
                let id = document.getElementById(text).dataset.appid;
                apps.push(id);
            }
        });
        GetLatencyChartData({
            timeUnit,
            apps,
            from,
            to,
            updateTab
        });
    }
}
