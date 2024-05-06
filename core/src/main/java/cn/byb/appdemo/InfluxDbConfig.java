package cn.byb.appdemo;

import cn.fraudmetrix.metrics.Registry;
import cn.fraudmetrix.metrics.RegistryReporter;
import cn.fraudmetrix.metrics.ServerInfoProvider;
import cn.fraudmetrix.metrics.TagProvider;
import cn.fraudmetrix.metrics.reporter.ConsoleReporter;
import cn.fraudmetrix.metrics.reporter.InfluxDBReporter;
import cn.fraudmetrix.metrics.reporter.Reporter;
import org.influxdb.InfluxDB;
import org.influxdb.InfluxDBFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.ArrayList;
import java.util.List;

/**
 * Created by byb on 24/5/6.
 * 习惯用java bean形式可参考此类
 */
@Configuration
public class InfluxDbConfig {

    @Value("${influxdb.url}")
    String influxUrl;

    // influxdb的client,用于往influxdb发送数据，配置来自于shutter，app=influxdb，file=influxdb.properties
    @Bean
    public InfluxDB influxDB() {
        return InfluxDBFactory.connect(influxUrl, "user", "pass");
    }

    // 负责将metrics数据汇报给influxdb
    @Bean
    public InfluxDBReporter influxDBReporter(InfluxDB influxDB, ServerInfoProvider serverInfoProvider) {
        InfluxDBReporter influxDBReporter = new InfluxDBReporter();
        List<TagProvider> tagProviders = new ArrayList<>();
        tagProviders.add(serverInfoProvider);
        influxDBReporter.setInfluxDB(influxDB);
        influxDBReporter.setTagProviders(tagProviders);
        influxDBReporter.setDatabase("appdemo");// 和应用名保持一致
        return influxDBReporter;
    }

    // 将metrics数据打印在控制台
    @Bean
    public ConsoleReporter consoleReporter() {
        return new ConsoleReporter();
    }

    @Bean
    public Registry registry() {
        return new Registry();
    }

    @Bean
    public ServerInfoProvider serverInfoProvider() {
        return new ServerInfoProvider();
    }

    // 从registry中读取数据,然后转交给具体的report进行汇报,线下可开启consoleReporter，生产环境要删掉consoleReporter
    @Bean
    public RegistryReporter registryReporter(Registry registry, InfluxDBReporter influxDBReporter) {
        RegistryReporter reporter = new RegistryReporter();
        reporter.setIsEnable(true);// true为开启，把指标上报到influxdb
        reporter.setRegistry(registry);
        reporter.setReportIntervalMillis(10000);// 上报频率10ms，不建议更改
        List<Reporter> reporters = new ArrayList<>();
        reporters.add(influxDBReporter);
        reporter.setReporters(reporters);
        reporter.init();
        return reporter;
    }

}
